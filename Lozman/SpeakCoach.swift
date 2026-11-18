import SwiftUI
import Observation

// MARK: - AI helper

enum CoachAI {
    static var isReady: Bool { !AssistantStore.geminiKey.isEmpty || AssistantStore.appleAvailable }

    @MainActor
    static func reply(system: String, history: [ChatMessage], onText: @escaping @MainActor (String) -> Void) async throws -> String {
        // Gemini wants the conversation to start with the user.
        var trimmed = history
        while let first = trimmed.first, !first.fromUser { trimmed.removeFirst() }
        if !AssistantStore.geminiKey.isEmpty {
            return try await GeminiEngine.stream(key: AssistantStore.geminiKey, model: AssistantStore.geminiModel,
                                                 system: system, history: trimmed, onText: onText)
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), AssistantStore.appleAvailable {
            var prompt = ""
            for m in trimmed.dropLast().suffix(8) {
                prompt += (m.fromUser ? "Student: " : "Coach: ") + m.text + "\n"
            }
            prompt += "Student: " + (trimmed.last?.text ?? "")
            let text = try await AppleEngine.reply(system: system, prompt: prompt)
            onText(text)
            return text
        }
        #endif
        throw GeminiEngine.Failure.message("Konuşma koçu için Ayarlar → Asistan bölümüne Gemini anahtarını ekle.")
    }
}

// MARK: - Speaking coach

struct CoachScenario: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let role: String
    let opener: String

    static let all: [CoachScenario] = [
        CoachScenario(id: "free", title: "Serbest sohbet", icon: "bubble.left.and.bubble.right.fill",
                      role: "a friendly English friend having a casual chat about daily life, work, football and plans",
                      opener: "Hey! How was your day? Tell me one thing you did today."),
        CoachScenario(id: "intro", title: "Kendini tanıt", icon: "person.crop.circle.fill",
                      role: "a new foreign colleague meeting him for the first time at an international meeting",
                      opener: "Hi, nice to meet you! I'm Sarah from the UK team. What do you do?"),
        CoachScenario(id: "water", title: "Su kurtarma brifingi", icon: "water.waves",
                      role: "a foreign swiftwater rescue team leader during a joint flood exercise. Ask about the river, the hazards, upstream spotters, downstream safety, throw bags, PPE and the rescue plan",
                      opener: "Morning! We're ready for the river exercise. Can you brief us on the conditions today?"),
        CoachScenario(id: "usar", title: "Deprem sahası (INSARAG)", icon: "building.2.crop.circle.fill",
                      role: "the leader of an international USAR team who just arrived after an earthquake. He is the liaison officer. Ask about the reception centre, worksites, sectors, logistics, water, fuel, transport, marking and reporting",
                      opener: "Hello, we just landed. Our team has 42 members and 4 search dogs. Where should we go first?"),
        CoachScenario(id: "train", title: "Eğitim verirken", icon: "person.3.fill",
                      role: "a participant in a disaster training he is teaching abroad. Ask simple questions about earthquake preparedness, family plans and first aid",
                      opener: "Excuse me, trainer, can I ask a question? What should my family do during an earthquake?"),
        CoachScenario(id: "airport", title: "Havalimanı & otel", icon: "airplane",
                      role: "an airline check-in agent, then a hotel receptionist",
                      opener: "Good evening, sir. Can I see your passport, please? Where are you flying today?"),
        CoachScenario(id: "doctor", title: "Doktorda", icon: "cross.case.fill",
                      role: "a doctor in a clinic abroad",
                      opener: "Hello, please have a seat. What seems to be the problem today?"),
        CoachScenario(id: "food", title: "Restoran & kafe", icon: "fork.knife",
                      role: "a waiter in a busy restaurant",
                      opener: "Hi there! Table for one? Can I get you something to drink first?"),
        CoachScenario(id: "meeting", title: "İş toplantısı", icon: "briefcase.fill",
                      role: "a colleague from a partner organisation in an online meeting about a joint workshop: dates, agenda, participants, budget",
                      opener: "Thanks for joining. Shall we start with the workshop dates? What works for your team?")
    ]
}

@Observable
final class CoachStore {
    var scenario = CoachScenario.all[0]
    var messages: [ChatMessage] = []
    var busy = false
    var error: String?
    var autoSpeak: Bool {
        get { UserDefaults.standard.object(forKey: "coachSpeak") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "coachSpeak") }
    }

    init() { reset() }

    func reset() {
        messages = [ChatMessage(fromUser: false, text: scenario.opener)]
        error = nil
    }

    private var system: String {
        """
        You are "Coach", a warm English speaking partner inside a Turkish user's personal app. \
        The user is Turkish, a search and rescue technician, B1 level. His biggest problem: when speaking, words don't come to his mind. \
        Role-play: you are \(scenario.role). Stay in the role.
        Rules:
        - Reply in simple, natural B1–B2 English. Maximum 2–3 short sentences. Always end with one question so he keeps talking.
        - If his message has a grammar or vocabulary mistake, add a new last line that starts exactly with "Düzeltme:" followed by the corrected sentence in English and a very short explanation in Turkish. If there is no mistake, do not add that line.
        - If he writes a Turkish word, or asks "what's the word for ...", give him the English word, then continue the role-play.
        - If he says "hint" or "ipucu", give him 3 useful English words or phrases for his next answer, each with its Turkish meaning, on one line.
        - Use useful words from the topic naturally so he hears them.
        - Never write long paragraphs, lists or markdown.
        """
    }

    @MainActor
    func send(_ raw: String) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        error = nil
        messages.append(ChatMessage(fromUser: true, text: text))
        let history = messages
        messages.append(ChatMessage(fromUser: false, text: "…"))
        let index = messages.count - 1
        busy = true
        defer { busy = false }
        do {
            let reply = try await CoachAI.reply(system: system, history: history) { [weak self] t in
                guard let self, index < self.messages.count else { return }
                self.messages[index].text = t
            }
            if index < messages.count { messages[index].text = reply }
            if autoSpeak { Sfx.say(Self.spokenPart(reply)) }
        } catch {
            if index < messages.count { messages.remove(at: index) }
            self.error = error.localizedDescription
        }
    }

    static func split(_ text: String) -> (main: String, fix: String?) {
        guard let r = text.range(of: "Düzeltme:") else { return (text, nil) }
        let main = String(text[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let fix = String(text[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (main, fix)
    }

    static func spokenPart(_ text: String) -> String { split(text).main }
}

struct SpeakCoachView: View {
    @State private var coach = CoachStore()
    @State private var listener = SpeechListener()
    @State private var draft = ""
    @State private var speak = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CoachScenario.all) { s in
                        Button {
                            listener.cancel()
                            coach.scenario = s
                            coach.reset()
                            if speak { Sfx.say(s.opener) }
                        } label: {
                            Label(s.title, systemImage: s.icon)
                                .font(.subheadline.weight(coach.scenario == s ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(coach.scenario == s ? Color.loz : Color(.secondarySystemBackground), in: Capsule())
                                .foregroundStyle(coach.scenario == s ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        if !CoachAI.isReady {
                            Text("Koçun çalışması için Ayarlar → Asistan bölümüne ücretsiz Gemini anahtarını ekle.")
                                .font(.callout)
                                .padding()
                                .background(Color.loz.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        }
                        ForEach(coach.messages) { m in bubble(m).id(m.id) }
                        if let e = coach.error {
                            Text(e).font(.caption).foregroundStyle(.red)
                        }
                        Text("Takıldığında “hint” de ya da Türkçe kelimeyi söyle: koç İngilizcesini verir.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                            .id("end")
                    }
                    .padding()
                }
                .onChange(of: coach.messages.last?.text) { _, _ in
                    withAnimation { proxy.scrollTo("end", anchor: .bottom) }
                }
            }

            inputBar
        }
        .navigationTitle("Konuşma koçu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle("Cevapları sesli oku", isOn: $speak)
                    Button("Sohbeti sıfırla", systemImage: "arrow.counterclockwise") {
                        listener.cancel()
                        coach.reset()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { speak = coach.autoSpeak }
        .onChange(of: speak) { _, v in coach.autoSpeak = v }
        .onDisappear {
            listener.cancel()
            Sfx.stopSpeaking()
        }
    }

    private var inputBar: some View {
        VStack(spacing: 6) {
            if listener.listening {
                Text(listener.text.isEmpty ? "Dinliyorum…" : listener.text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let p = listener.problem {
                Text(p).font(.caption).foregroundStyle(.red)
            }
            HStack(spacing: 10) {
                Button {
                    listener.onFinish = { text in
                        let t = text.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty else { return }
                        Task { await coach.send(t) }
                    }
                    Task { await listener.toggle() }
                } label: {
                    Image(systemName: listener.listening ? "stop.fill" : "mic.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(listener.listening ? Color.red : Color.loz, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(coach.busy)
                .accessibilityLabel(listener.listening ? "Dinlemeyi durdur" : "Konuş")

                TextField("Yaz ya da mikrofona bas", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                Button {
                    let t = draft
                    draft = ""
                    Task { await coach.send(t) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || coach.busy)
            }
            HStack {
                Button("İpucu ver") { Task { await coach.send("hint") } }
                Spacer()
                Button("Daha yavaş tekrar") {
                    if let last = coach.messages.last(where: { !$0.fromUser }) {
                        Sfx.say(CoachStore.spokenPart(last.text), slow: true)
                    }
                }
            }
            .font(.caption.weight(.medium))
            .disabled(coach.busy)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private func bubble(_ m: ChatMessage) -> some View {
        let parts = CoachStore.split(m.text)
        HStack {
            if m.fromUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                Text(parts.main)
                if let fix = parts.fix {
                    Label(fix, systemImage: "pencil.circle.fill")
                        .font(.callout)
                        .foregroundStyle(Color.loz)
                        .padding(8)
                        .background(Color.loz.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                if !m.fromUser && m.text != "…" {
                    Button {
                        Sfx.say(parts.main)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill").font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(m.fromUser ? Color.loz : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(m.fromUser ? Color.white : Color.primary)
            if !m.fromUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Lifesaver phrases

struct Phrase: Hashable {
    let en: String
    let tr: String
}

struct PhraseGroup: Identifiable {
    let id: String
    let icon: String
    let note: String
    let phrases: [Phrase]

    static let all: [PhraseGroup] = [
        PhraseGroup(id: "Kelime aklına gelmeyince", icon: "lifepreserver.fill",
                    note: "Kelimeyi bilmesen de konuşmayı durdurma: tarif et. Ana dili İngilizce olanlar da bunu yapar.",
                    phrases: [
                        Phrase(en: "It's a kind of ...", tr: "Bir çeşit ..."),
                        Phrase(en: "It's something you use to ...", tr: "... yapmak için kullandığın bir şey"),
                        Phrase(en: "It's the person who ...", tr: "... yapan kişi"),
                        Phrase(en: "It's the place where ...", tr: "... yapılan yer"),
                        Phrase(en: "It's like a ..., but bigger.", tr: "... gibi ama daha büyük"),
                        Phrase(en: "It's the opposite of ...", tr: "...'in tersi"),
                        Phrase(en: "I don't know the word in English, but ...", tr: "İngilizcesini bilmiyorum ama ..."),
                        Phrase(en: "What do you call the thing that ...?", tr: "... olan şeye ne diyorsunuz?"),
                        Phrase(en: "How do you say ... in English?", tr: "... İngilizcede nasıl denir?"),
                        Phrase(en: "It's on the tip of my tongue.", tr: "Dilimin ucunda."),
                        Phrase(en: "Sorry, I can't remember the word.", tr: "Pardon, kelimeyi hatırlayamıyorum.")
                    ]),
        PhraseGroup(id: "Zaman kazan", icon: "hourglass",
                    note: "Düşünürken sessiz kalma; bu kalıplar sana 2–3 saniye kazandırır.",
                    phrases: [
                        Phrase(en: "Let me think for a second.", tr: "Bir saniye düşüneyim."),
                        Phrase(en: "That's a good question.", tr: "Güzel soru."),
                        Phrase(en: "How can I put it ...", tr: "Nasıl desem ..."),
                        Phrase(en: "Well, the thing is ...", tr: "Şey, mesele şu ki ..."),
                        Phrase(en: "What I'm trying to say is ...", tr: "Demeye çalıştığım şu ..."),
                        Phrase(en: "In other words ...", tr: "Başka bir deyişle ..."),
                        Phrase(en: "Give me a moment.", tr: "Bana bir dakika ver.")
                    ]),
        PhraseGroup(id: "Anlamadığında", icon: "questionmark.bubble.fill",
                    note: "Anlamamak sorun değil; sormamak sorun.",
                    phrases: [
                        Phrase(en: "Sorry, could you say that again?", tr: "Pardon, tekrar söyler misin?"),
                        Phrase(en: "Could you speak a bit more slowly, please?", tr: "Biraz daha yavaş konuşabilir misin?"),
                        Phrase(en: "What do you mean by ...?", tr: "... ile ne demek istiyorsun?"),
                        Phrase(en: "Do you mean ...?", tr: "... mı demek istiyorsun?"),
                        Phrase(en: "Let me check I understand.", tr: "Doğru anladım mı kontrol edeyim."),
                        Phrase(en: "Could you write it down for me?", tr: "Benim için yazabilir misin?")
                    ]),
        PhraseGroup(id: "Fikrini söyle", icon: "hand.raised.fill",
                    note: "Toplantıda ve sohbette konuşmaya girmek için.",
                    phrases: [
                        Phrase(en: "In my opinion, ...", tr: "Bence ..."),
                        Phrase(en: "I see your point, but ...", tr: "Ne demek istediğini anlıyorum ama ..."),
                        Phrase(en: "I totally agree.", tr: "Kesinlikle katılıyorum."),
                        Phrase(en: "I'm not sure about that.", tr: "Ondan emin değilim."),
                        Phrase(en: "Can I add something?", tr: "Bir şey ekleyebilir miyim?"),
                        Phrase(en: "What about ...?", tr: "Peki ya ...?"),
                        Phrase(en: "Let's move on to the next point.", tr: "Sonraki maddeye geçelim.")
                    ]),
        PhraseGroup(id: "Saha ve telsiz", icon: "antenna.radiowaves.left.and.right",
                    note: "Operasyonda kısa ve net konuş.",
                    phrases: [
                        Phrase(en: "Copy that.", tr: "Anlaşıldı."),
                        Phrase(en: "Say again.", tr: "Tekrar et."),
                        Phrase(en: "Stand by.", tr: "Beklemede kal."),
                        Phrase(en: "What's your location?", tr: "Konumun neresi?"),
                        Phrase(en: "We have a live victim in sector B.", tr: "B sektöründe canlı kazazede var."),
                        Phrase(en: "We need a silent period. Everybody stop.", tr: "Sessizlik anı lazım. Herkes dursun."),
                        Phrase(en: "The structure is not safe. Pull back.", tr: "Yapı güvenli değil. Geri çekilin."),
                        Phrase(en: "Request medical support at this worksite.", tr: "Bu sahaya sağlık desteği istiyoruz."),
                        Phrase(en: "All team members are accounted for.", tr: "Tüm ekip tam, kayıp yok."),
                        Phrase(en: "Upstream spotter in position.", tr: "Akıntı yukarısı gözcüsü yerinde."),
                        Phrase(en: "Rope! Rope! Rope!", tr: "İp atılıyor! (atma torbası uyarısı)"),
                        Phrase(en: "Swimmer in the water.", tr: "Suda kurtarıcı yüzücü var.")
                    ]),
        PhraseGroup(id: "Uluslararası ekiple", icon: "globe.europe.africa.fill",
                    note: "İrtibat görevlisi olarak ilk dakikalar.",
                    phrases: [
                        Phrase(en: "Welcome to Türkiye. I'm your liaison officer.", tr: "Türkiye'ye hoş geldiniz. İrtibat görevliniz benim."),
                        Phrase(en: "How many members and dogs are in your team?", tr: "Ekibinizde kaç kişi ve köpek var?"),
                        Phrase(en: "Do you need water, fuel or transport?", tr: "Su, yakıt ya da ulaşıma ihtiyacınız var mı?"),
                        Phrase(en: "Your base of operations will be here.", tr: "Operasyon üssünüz burası olacak."),
                        Phrase(en: "Please report to the coordination centre.", tr: "Lütfen koordinasyon merkezine bildirin."),
                        Phrase(en: "Please send your daily report by 8 p.m.", tr: "Günlük raporunuzu akşam 8'e kadar gönderin."),
                        Phrase(en: "Your assigned sector is shown on this map.", tr: "Size verilen sektör bu haritada.")
                    ])
    ]
}

struct PhrasesView: View {
    @State private var listener = SpeechListener()
    @State private var practicing: Phrase?
    @State private var result: [Phrase: Bool] = [:]

    var body: some View {
        List {
            Section {
                Text("Kelime aklına gelmediğinde donup kalma. Bu kalıpları sesli tekrar et; refleks hâline gelsin. Dinlemek için satıra, kendini denemek için mikrofona bas.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(PhraseGroup.all) { g in
                Section {
                    ForEach(g.phrases, id: \.self) { p in row(p) }
                } header: {
                    Label(g.id, systemImage: g.icon)
                } footer: {
                    Text(g.note)
                }
            }
        }
        .navigationTitle("Kurtarıcı kalıplar")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { listener.cancel() }
    }

    private func row(_ p: Phrase) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(p.en).font(.body.weight(.medium))
                Text(p.tr).font(.caption).foregroundStyle(.secondary)
                if practicing == p && listener.listening {
                    Text(listener.text.isEmpty ? "Dinliyorum…" : listener.text)
                        .font(.caption)
                        .foregroundStyle(Color.loz)
                }
            }
            Spacer()
            if let ok = result[p] {
                Image(systemName: ok ? "checkmark.circle.fill" : "arrow.clockwise.circle")
                    .foregroundStyle(ok ? Color.green : Color.orange)
            }
            Button {
                practicing = p
                listener.onFinish = { text in
                    let ok = SpeechListener.overlap(p.en.replacingOccurrences(of: "...", with: ""), text) >= 0.7
                    result[p] = ok
                    if ok { Sfx.play("correct"); Sfx.success() } else { Sfx.bump() }
                }
                Task { await listener.toggle() }
            } label: {
                Image(systemName: listener.listening && practicing == p ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(listener.listening && practicing == p ? Color.red : Color.loz)
            }
            .buttonStyle(.borderless)
        }
        .contentShape(Rectangle())
        .onTapGesture { Sfx.say(p.en.replacingOccurrences(of: "...", with: "")) }
    }
}

// MARK: - Word list

struct WordListView: View {
    @State private var search = ""
    @State private var category = WordGame.allCategories
    @State private var open: String?
    private let progress: GameProgress = {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("words-progress.json")
        if let data = try? Data(contentsOf: url), let p = try? JSONDecoder().decode(GameProgress.self, from: data) { return p }
        return GameProgress()
    }()

    private var words: [Word] {
        var list = WordBank.all
        if category != WordGame.allCategories { list = list.filter { $0.category == category } }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.en.lowercased().contains(q) || $0.tr.lowercased().contains(q) }
        }
        return list.sorted { $0.en.lowercased() < $1.en.lowercased() }
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip(WordGame.allCategories, icon: "square.grid.2x2", count: WordBank.all.count)
                        ForEach(WordBank.categories, id: \.self) { c in
                            chip(c, icon: WordBank.icon(for: c), count: WordBank.all.filter { $0.category == c }.count)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
            Section("\(words.count) kelime") {
                ForEach(words, id: \.en) { w in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(w.en).font(.body.weight(.semibold))
                            Text(w.level)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.loz)
                            Spacer()
                            stars(progress.box[w.en] ?? 0)
                        }
                        Text(w.tr).font(.subheadline).foregroundStyle(.secondary)
                        if open == w.en {
                            Text(w.clue).font(.caption)
                            Text(w.ex).font(.caption).italic()
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        open = open == w.en ? nil : w.en
                        Sfx.say(w.en)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "İngilizce ya da Türkçe ara")
        .navigationTitle("Kelime listesi")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chip(_ c: String, icon: String, count: Int) -> some View {
        Button {
            category = c
        } label: {
            Label("\(c == WordGame.allCategories ? "Tümü" : c) \(count)", systemImage: icon)
                .font(.caption.weight(category == c ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(category == c ? Color.loz : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(category == c ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func stars(_ box: Int) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: box >= (i + 1) * 2 ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(box >= (i + 1) * 2 ? Color.yellow : Color.secondary.opacity(0.4))
            }
        }
        .accessibilityLabel("Öğrenme \(box)/6")
    }
}

// MARK: - Hub

struct EnglishHubView: View {
    var body: some View {
        List {
            Section {
                Text("Kelimeler aklına gelmiyorsa sorun bilmemek değil, hatırlamayı az çalıştırmak. Her gün: önce Günün tekrarı, sonra Söyle, sonra koçla 5 dakika konuş.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Her gün") {
                NavigationLink { WordGameView(startMode: .review) } label: {
                    Label("Günün tekrarı", systemImage: "repeat.circle.fill")
                }
                NavigationLink { WordGameView(startMode: .speak) } label: {
                    Label("Söyle: kelimeyi sesli hatırla", systemImage: "mic.fill")
                }
                NavigationLink { SpeakCoachView() } label: {
                    Label("Konuşma koçu", systemImage: "person.wave.2.fill")
                }
            }
            Section("Araçlar") {
                NavigationLink { WordGameView(startMode: .build) } label: {
                    Label("Cümle kur", systemImage: "text.bubble.fill")
                }
                NavigationLink { PhrasesView() } label: {
                    Label("Kurtarıcı kalıplar", systemImage: "lifepreserver.fill")
                }
                NavigationLink { WordListView() } label: {
                    Label("Kelime listesi (\(WordBank.all.count))", systemImage: "list.bullet.rectangle.fill")
                }
                NavigationLink { WordGameView(startMode: .reverse) } label: {
                    Label("Tüm kelime oyunları", systemImage: "gamecontroller.fill")
                }
            }
        }
        .navigationTitle("İngilizce")
    }
}
