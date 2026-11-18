import SwiftUI

struct WordGameView: View {
    var startMode: GameMode = .review
    @State private var game = WordGame()
    @State private var soundOn = Sfx.soundOn
    @State private var listener = SpeechListener()
    @State private var typed = ""
    @State private var didStart = false
    @FocusState private var answerFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    header
                    modeChips
                    filters
                    Text(game.mode.help)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if game.mistakesEmpty {
                        emptyCard(icon: "checkmark.seal.fill", title: "Hata listen boş",
                                  text: "Yanlış yaptığın kelimeler burada birikir. Doğru bildiğinde listeden çıkar.")
                    } else if game.empty && game.mode == .review {
                        emptyCard(icon: "party.popper.fill", title: "Bugünlük tekrar bitti",
                                  text: "Yarın yeni kelimeler ve tekrar zamanı gelenler burada olacak. İstersen Söyle modunda devam et.")
                    } else if game.empty {
                        emptyCard(icon: "tray", title: "Bu filtrede kelime yok", text: "Seviyeyi veya konuyu değiştir.")
                    } else {
                        Group {
                            switch game.mode {
                            case .review, .reverse: choiceCard(reverse: true)
                            case .meaning, .mistakes: choiceCard(reverse: false)
                            case .speak: speakCard
                            case .build: buildCard
                            case .sentence: sentenceCard
                            case .riddle: riddleCard
                            }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .padding()
            }
            .onChange(of: game.answered) { _, done in
                if done {
                    withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if game.answered { nextBar }
        }
        .overlay(alignment: .top) { rewardBanner }
        .overlay { ConfettiView(trigger: game.confetti).allowsHitTesting(false) }
        .navigationTitle("Kelime antrenmanı")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    soundOn.toggle()
                    Sfx.soundOn = soundOn
                } label: {
                    Image(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .accessibilityLabel(soundOn ? "Sesi kapat" : "Sesi aç")
            }
        }
        .onAppear {
            if !didStart {
                didStart = true
                if game.mode != startMode { game.mode = startMode }
            }
        }
        .onDisappear { listener.cancel() }
        .onChange(of: game.level) { _, _ in restart() }
        .onChange(of: game.mode) { _, _ in restart() }
        .onChange(of: game.category) { _, c in
            UserDefaults.standard.set(c, forKey: "wordCategory")
            restart()
        }
    }

    private func restart() {
        listener.cancel()
        typed = ""
        game.combo = 0
        game.next()
    }

    private func goNext() {
        listener.cancel()
        typed = ""
        withAnimation(.snappy) {
            game.reward = nil
            game.next()
        }
        if game.mode == .riddle { answerFocused = true }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.loz.opacity(0.18), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(1, Double(game.todayCount) / Double(WordGame.dailyGoal)))
                    .stroke(Color.loz, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy, value: game.todayCount)
                VStack(spacing: 0) {
                    Text("\(game.todayCount)").font(.subheadline.weight(.bold).monospacedDigit())
                    Text("/\(WordGame.dailyGoal)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 52, height: 52)
            .accessibilityLabel("Bugün \(game.todayCount) doğru, hedef \(WordGame.dailyGoal)")

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Seviye \(game.playerLevel)").font(.headline)
                    Spacer()
                    Label("\(game.combo)", systemImage: "flame.fill")
                        .foregroundStyle(game.combo >= 3 ? Color.orange : Color.secondary)
                    Label("\(game.dayStreak)", systemImage: "calendar")
                        .foregroundStyle(Color.loz)
                    Label("\(game.learnedCount)", systemImage: "brain.head.profile")
                        .foregroundStyle(.purple)
                }
                .font(.caption.weight(.semibold).monospacedDigit())
                ProgressView(value: game.levelProgress).tint(.loz)
                    .animation(.snappy, value: game.progress.xp)
                Text("\(game.progress.xp) XP · sonraki seviyeye \(game.xpToNext) · öğrenilen \(game.learnedCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var modeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GameMode.allCases) { m in
                    Button {
                        game.mode = m
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: m.icon)
                            Text(m.rawValue)
                            if m == .review && game.reviewLeft > 0 {
                                Text("\(game.reviewLeft)")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 5)
                                    .background(Color.white.opacity(game.mode == m ? 0.3 : 0), in: Capsule())
                            }
                        }
                        .font(.subheadline.weight(game.mode == m ? .semibold : .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(game.mode == m ? Color.loz : Color(.secondarySystemBackground), in: Capsule())
                        .foregroundStyle(game.mode == m ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var filters: some View {
        if game.mode != .mistakes {
            HStack(spacing: 8) {
                Picker("Seviye", selection: $game.level) {
                    ForEach(GameLevel.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Menu {
                    Picker("Konu", selection: $game.category) {
                        Label("Tüm konular", systemImage: "square.grid.2x2").tag(WordGame.allCategories)
                        ForEach(WordBank.categories, id: \.self) { c in
                            Label(c, systemImage: WordBank.icon(for: c)).tag(c)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: game.category == WordGame.allCategories ? "square.grid.2x2" : WordBank.icon(for: game.category))
                        Text(game.category == WordGame.allCategories ? "Konu" : game.category)
                            .lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.loz.opacity(0.12), in: Capsule())
                    .foregroundStyle(Color.loz)
                }
                .frame(maxWidth: 150)
            }
        }
    }

    private func emptyCard(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(Color.loz)
            Text(title).font(.headline)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }

    private var levelBadge: some View {
        HStack(spacing: 6) {
            Text(game.current.level)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.loz.opacity(0.15), in: Capsule())
                .foregroundStyle(Color.loz)
            Label(game.current.category, systemImage: WordBank.icon(for: game.current.category))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if game.mode == .mistakes {
                Text("\(game.progress.mistakes.count) hatalı")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if game.mode == .review {
                Text(game.progress.box[game.current.en] == nil ? "YENİ" : "Tekrar")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(game.progress.box[game.current.en] == nil ? Color.green : Color.purple)
            }
        }
    }

    private func speakButton(_ text: String) -> some View {
        Button {
            Sfx.say(text)
        } label: {
            Image(systemName: "speaker.wave.2.circle.fill")
                .font(.title)
                .foregroundStyle(Color.loz)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Telaffuzu dinle")
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 14, content: content)
            .padding()
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08)))
    }

    // MARK: Multiple choice

    private func choiceCard(reverse: Bool) -> some View {
        card {
            levelBadge
            HStack(spacing: 10) {
                Text(reverse ? game.current.tr : game.current.en)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                if !reverse { speakButton(game.current.en) }
            }
            Text(reverse ? "İngilizcesi hangisi? Önce aklından söyle, sonra seç." : game.current.clue)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                ForEach(game.options, id: \.self) { option in
                    Button {
                        withAnimation(.snappy) { game.pick(option) }
                        if reverse && option.en == game.current.en { Sfx.say(option.en) }
                    } label: {
                        HStack {
                            Text(reverse ? option.en : option.tr)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if let picked = game.picked {
                                if option.en == game.current.en {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else if option.en == picked.en {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(14)
                        .background(optionColor(option), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(game.picked != nil)
                }
            }
            if let picked = game.picked {
                answerFooter(correct: picked.en == game.current.en)
            }
        }
    }

    private func answerFooter(correct: Bool) -> some View {
        VStack(spacing: 10) {
            Text(correct ? "Doğru!" : "Doğrusu: \(game.current.en) = \(game.current.tr)")
                .font(.headline)
                .foregroundStyle(correct ? Color.green : Color.red)
            VStack(alignment: .leading, spacing: 6) {
                Text(game.current.clue).font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.opening").foregroundStyle(.secondary)
                    Text(game.current.ex).italic()
                    Spacer(minLength: 0)
                    Button {
                        Sfx.say(game.current.ex)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                    }
                    .accessibilityLabel("Cümleyi dinle")
                }
                .font(.callout)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            if let box = game.progress.box[game.current.en], let due = game.progress.due[game.current.en] {
                Text(correct ? "Tekrar: \(Day.diff(due) <= 0 ? "bugün" : "\(Day.diff(due)) gün sonra") · kutu \(box)/6"
                             : "Bu kelime bugün tekrar karşına çıkacak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func optionColor(_ option: Word) -> Color {
        guard let picked = game.picked else { return Color(.secondarySystemBackground) }
        if option.en == game.current.en { return Color.green.opacity(0.18) }
        if option.en == picked.en { return Color.red.opacity(0.18) }
        return Color(.secondarySystemBackground)
    }

    // MARK: Speak the word

    private var speakCard: some View {
        card {
            levelBadge
            Text(game.current.tr)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
            Text("İngilizcesini sesli söyle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if game.spoken == nil {
                if game.speakHint > 0 {
                    Text(game.speakPattern)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.loz)
                        .multilineTextAlignment(.center)
                }
                if game.speakHint > 1 {
                    Text(game.current.clue)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
                micButton { text in game.checkSpoken(text) }
                if !listener.text.isEmpty || !game.heard.isEmpty {
                    Text("Duyulan: “\(listener.listening ? listener.text : game.heard)”")
                        .font(.callout)
                        .foregroundStyle(listener.listening ? Color.primary : Color.red)
                        .multilineTextAlignment(.center)
                    if !listener.listening && !game.heard.isEmpty {
                        Text("Olmadı, tekrar dene ya da ipucu al.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    Button("İpucu") {
                        game.speakHint += 1
                        if game.speakHint > 2 { game.speakHint = 2 }
                    }
                    .disabled(game.speakHint >= 2)
                    Button("Cevabı göster") {
                        listener.cancel()
                        game.revealSpoken()
                    }
                }
                .buttonStyle(.bordered)
                .font(.subheadline)
            } else {
                HStack(spacing: 10) {
                    Text(game.current.en)
                        .font(.title.weight(.bold))
                        .foregroundStyle(game.spoken == true ? Color.green : Color.loz)
                    speakButton(game.current.en)
                }
                answerFooter(correct: game.spoken == true)
            }
        }
    }

    private func micButton(onResult: @escaping (String) -> Void) -> some View {
        VStack(spacing: 6) {
            Button {
                listener.onFinish = onResult
                Task { await listener.toggle() }
            } label: {
                ZStack {
                    Circle()
                        .fill(listener.listening ? Color.red : Color.loz)
                        .frame(width: 78, height: 78)
                        .shadow(color: (listener.listening ? Color.red : Color.loz).opacity(0.35), radius: 10, y: 4)
                    Image(systemName: listener.listening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(listener.listening ? 1.08 : 1)
                .animation(.easeInOut(duration: 0.6).pulsing(listener.listening), value: listener.listening)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(listener.listening ? "Dinlemeyi durdur" : "Konuşmaya başla")
            Text(listener.listening ? "Dinliyorum…" : "Bas ve konuş")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let p = listener.problem {
                Text(p).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Build a sentence

    private var buildCard: some View {
        card {
            levelBadge
            HStack(spacing: 10) {
                Text(game.current.en)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                speakButton(game.current.en)
            }
            Text(game.current.tr).foregroundStyle(.secondary)
            Text("Bu kelimeyle kendi hayatından bir cümle kur ve sesli söyle (en az 4 kelime).")
                .font(.callout)
                .multilineTextAlignment(.center)

            if game.built == nil {
                micButton { text in
                    typed = text
                    game.checkBuilt(text)
                }
                if listener.listening && !listener.text.isEmpty {
                    Text("“\(listener.text)”").font(.callout)
                }
                HStack {
                    TextField("ya da yaz…", text: $typed, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.sentences)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    Button {
                        game.checkBuilt(typed)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title)
                    }
                    .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !game.builtSentence.isEmpty {
                    Text("“\(game.builtSentence)” — kelimeyi kullandığın en az 4 kelimelik bir cümle olmalı.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("Örneği göster, geç") {
                    listener.cancel()
                    game.skipBuilt()
                }
                .font(.footnote)
            } else {
                if game.built == true {
                    Text("“\(game.builtSentence)”")
                        .font(.callout.weight(.medium))
                        .multilineTextAlignment(.center)
                }
                answerFooter(correct: game.built == true)
                if game.built == true {
                    if let note = game.coachNote {
                        Text(note)
                            .font(.callout)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.loz.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Button {
                            Task { await game.askCoach() }
                        } label: {
                            Label(game.coachBusy ? "Bakılıyor…" : "Koça düzelttir", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)
                        .disabled(game.coachBusy || !CoachAI.isReady)
                        if !CoachAI.isReady {
                            Text("Düzeltme için Ayarlar'a Gemini anahtarı ekle.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Fill the gap

    private var sentenceCard: some View {
        card {
            levelBadge
            Text("Boşluğa hangi kelime gelir?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(game.picked == nil ? game.hiddenSentence : game.current.ex)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
            VStack(spacing: 10) {
                ForEach(game.options, id: \.self) { option in
                    Button {
                        withAnimation(.snappy) { game.pick(option) }
                        if option.en == game.current.en { Sfx.say(game.current.ex) }
                    } label: {
                        HStack {
                            Text(option.en).font(.body.weight(.medium))
                            if game.picked != nil {
                                Text("· \(option.tr)").foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let picked = game.picked {
                                if option.en == game.current.en {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else if option.en == picked.en {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(14)
                        .background(optionColor(option), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(game.picked != nil)
                }
            }
            if let picked = game.picked {
                Text(picked.en == game.current.en ? "Doğru!" : "Doğrusu: \(game.current.en) = \(game.current.tr)")
                    .font(.headline)
                    .foregroundStyle(picked.en == game.current.en ? Color.green : Color.red)
            }
        }
    }

    // MARK: Riddle

    private var riddleCard: some View {
        card {
            levelBadge
            Text(game.current.clue)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(game.riddleSolved == nil ? game.pattern : game.current.en.uppercased())
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(game.riddleSolved == false ? Color.red : Color.loz)
                .multilineTextAlignment(.center)
            Text("\(game.current.en.filter { $0 != " " }.count) harf")
                .font(.caption)
                .foregroundStyle(.secondary)
            if game.showSentence && game.riddleSolved == nil {
                Text(game.hiddenSentence)
                    .font(.callout)
                    .italic()
                    .multilineTextAlignment(.center)
            }
            if game.showTurkish && game.riddleSolved == nil {
                Text("Türkçesi: \(game.current.tr)").foregroundStyle(.secondary)
            }
            if game.riddleSolved == nil {
                TextField("Cevabını yaz", text: $game.guess)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($answerFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        if !game.check() { answerFocused = true }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                Button {
                    if !game.check() { answerFocused = true }
                } label: {
                    Text("Kontrol et").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                HStack(spacing: 8) {
                    Button("Harf ver") { game.hintLetter() }
                    Button("Cümle") { game.showSentence = true }.disabled(game.showSentence)
                    Button("Türkçesi") { game.showTurkish = true }.disabled(game.showTurkish)
                }
                .buttonStyle(.bordered)
                .font(.subheadline)
                Button("Pes et", role: .destructive) { game.giveUp() }
                    .font(.footnote)
            } else {
                Text("\(game.current.en) = \(game.current.tr)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                answerFooter(correct: game.riddleSolved == true)
                    .onAppear { if game.riddleSolved == true { Sfx.say(game.current.en) } }
            }
        }
    }

    // MARK: Pinned bottom bar

    private var nextBar: some View {
        HStack(spacing: 10) {
            Button {
                Sfx.say(game.current.en)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title3)
                    .frame(width: 52, height: 52)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Kelimeyi dinle")
            Button {
                goNext()
            } label: {
                HStack {
                    Text("Sonraki kelime")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(game.lastAnswerCorrect ? Color.green : Color.loz, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.bar)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private var rewardBanner: some View {
        if let r = game.reward {
            Text(r.text)
                .font(r.big ? .title3.weight(.heavy) : .headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(r.big ? Color.loz : Color.green, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(r.id)
                .task(id: r.id) {
                    try? await Task.sleep(nanoseconds: r.big ? 2_200_000_000 : 1_100_000_000)
                    withAnimation(.easeOut) {
                        if game.reward?.id == r.id { game.reward = nil }
                    }
                }
        }
    }
}

private extension Animation {
    func pulsing(_ on: Bool) -> Animation {
        on ? self.repeatForever(autoreverses: true) : self
    }
}
