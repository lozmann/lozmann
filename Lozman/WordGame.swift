import SwiftUI
import Observation

struct Word: Hashable {
    let en: String
    let tr: String
    let level: String
    let clue: String
}

enum WordBank {
    static let all: [Word] = a2 + b1

    static let a2: [Word] = [
        Word(en: "borrow", tr: "ödünç almak", level: "A2", clue: "To take something from someone and give it back later."),
        Word(en: "cheap", tr: "ucuz", level: "A2", clue: "It does not cost a lot of money."),
        Word(en: "expensive", tr: "pahalı", level: "A2", clue: "It costs a lot of money."),
        Word(en: "journey", tr: "yolculuk", level: "A2", clue: "Travelling from one place to another, often a long way."),
        Word(en: "library", tr: "kütüphane", level: "A2", clue: "A building where you can read or borrow books."),
        Word(en: "neighbour", tr: "komşu", level: "A2", clue: "A person who lives next to you."),
        Word(en: "umbrella", tr: "şemsiye", level: "A2", clue: "You hold it over your head when it rains."),
        Word(en: "kitchen", tr: "mutfak", level: "A2", clue: "The room where you cook food."),
        Word(en: "invite", tr: "davet etmek", level: "A2", clue: "To ask someone to come to a party or an event."),
        Word(en: "remember", tr: "hatırlamak", level: "A2", clue: "To keep something in your mind; the opposite of forget."),
        Word(en: "forget", tr: "unutmak", level: "A2", clue: "To not remember something."),
        Word(en: "healthy", tr: "sağlıklı", level: "A2", clue: "Good for your body, or not ill."),
        Word(en: "dangerous", tr: "tehlikeli", level: "A2", clue: "Something that can hurt you."),
        Word(en: "quiet", tr: "sessiz", level: "A2", clue: "Making very little noise."),
        Word(en: "noisy", tr: "gürültülü", level: "A2", clue: "Making a lot of loud sound."),
        Word(en: "hungry", tr: "aç", level: "A2", clue: "How you feel when you want to eat."),
        Word(en: "thirsty", tr: "susamış", level: "A2", clue: "How you feel when you want to drink."),
        Word(en: "tired", tr: "yorgun", level: "A2", clue: "How you feel when you need to rest or sleep."),
        Word(en: "angry", tr: "kızgın", level: "A2", clue: "A strong bad feeling when someone does something wrong to you."),
        Word(en: "bored", tr: "sıkılmış", level: "A2", clue: "How you feel when nothing is interesting."),
        Word(en: "clever", tr: "zeki", level: "A2", clue: "Able to learn and understand things quickly."),
        Word(en: "lazy", tr: "tembel", level: "A2", clue: "Not wanting to work or do anything."),
        Word(en: "brave", tr: "cesur", level: "A2", clue: "Not afraid to do dangerous or difficult things."),
        Word(en: "polite", tr: "kibar", level: "A2", clue: "Speaking and acting in a nice, respectful way."),
        Word(en: "village", tr: "köy", level: "A2", clue: "A very small town in the countryside."),
        Word(en: "bridge", tr: "köprü", level: "A2", clue: "You walk or drive over it to cross a river."),
        Word(en: "river", tr: "nehir", level: "A2", clue: "A long line of water that flows to the sea."),
        Word(en: "mountain", tr: "dağ", level: "A2", clue: "A very high hill."),
        Word(en: "island", tr: "ada", level: "A2", clue: "Land with water all around it."),
        Word(en: "forest", tr: "orman", level: "A2", clue: "A large area with many trees."),
        Word(en: "wallet", tr: "cüzdan", level: "A2", clue: "A small case for your money and cards."),
        Word(en: "ticket", tr: "bilet", level: "A2", clue: "A small paper you buy to take a bus or see a film."),
        Word(en: "luggage", tr: "bagaj, valiz", level: "A2", clue: "The bags you take on a trip."),
        Word(en: "arrive", tr: "varmak", level: "A2", clue: "To get to a place."),
        Word(en: "earn", tr: "(para) kazanmak", level: "A2", clue: "To get money for the work you do."),
        Word(en: "spend", tr: "harcamak", level: "A2", clue: "To use money to buy things."),
        Word(en: "lose", tr: "kaybetmek", level: "A2", clue: "To not be able to find something, or to not win."),
        Word(en: "build", tr: "inşa etmek", level: "A2", clue: "To make a house or a building."),
        Word(en: "choose", tr: "seçmek", level: "A2", clue: "To decide which one you want."),
        Word(en: "decide", tr: "karar vermek", level: "A2", clue: "To make a choice after thinking."),
        Word(en: "explain", tr: "açıklamak", level: "A2", clue: "To tell someone about something so they understand it."),
        Word(en: "believe", tr: "inanmak", level: "A2", clue: "To think that something is true."),
        Word(en: "carry", tr: "taşımak", level: "A2", clue: "To hold something and take it with you."),
        Word(en: "climb", tr: "tırmanmak", level: "A2", clue: "To go up a mountain, a tree or a wall."),
        Word(en: "wear", tr: "giymek", level: "A2", clue: "To have clothes on your body."),
        Word(en: "medicine", tr: "ilaç", level: "A2", clue: "Something you take when you are ill."),
        Word(en: "headache", tr: "baş ağrısı", level: "A2", clue: "A pain in your head."),
        Word(en: "dentist", tr: "diş hekimi", level: "A2", clue: "A doctor who looks after your teeth."),
        Word(en: "holiday", tr: "tatil", level: "A2", clue: "Time when you do not work and often travel."),
        Word(en: "weekend", tr: "hafta sonu", level: "A2", clue: "Saturday and Sunday."),
        Word(en: "early", tr: "erken", level: "A2", clue: "Before the usual or planned time."),
        Word(en: "late", tr: "geç", level: "A2", clue: "After the usual or planned time."),
        Word(en: "busy", tr: "meşgul", level: "A2", clue: "Having a lot of things to do."),
        Word(en: "favourite", tr: "en sevdiği", level: "A2", clue: "The one you like the most."),
        Word(en: "difficult", tr: "zor", level: "A2", clue: "Not easy."),
        Word(en: "important", tr: "önemli", level: "A2", clue: "It matters a lot."),
        Word(en: "strange", tr: "garip", level: "A2", clue: "Unusual or surprising."),
        Word(en: "message", tr: "mesaj", level: "A2", clue: "Words you send to someone by phone or email."),
        Word(en: "meeting", tr: "toplantı", level: "A2", clue: "When people come together to talk about work."),
        Word(en: "hospital", tr: "hastane", level: "A2", clue: "A place where doctors and nurses care for ill people."),
        Word(en: "pharmacy", tr: "eczane", level: "A2", clue: "A shop where you buy medicine."),
        Word(en: "pocket", tr: "cep", level: "A2", clue: "A small bag sewn into your clothes."),
        Word(en: "dream", tr: "rüya, hayal", level: "A2", clue: "Pictures and stories in your mind when you sleep."),
        Word(en: "hurry", tr: "acele etmek", level: "A2", clue: "To move or do something quickly because you have little time."),
        Word(en: "wait", tr: "beklemek", level: "A2", clue: "To stay somewhere until something happens."),
        Word(en: "repair", tr: "tamir etmek", level: "A2", clue: "To fix something that is broken.")
    ]

    static let b1: [Word] = [
        Word(en: "achieve", tr: "başarmak", level: "B1", clue: "To succeed in doing something after working hard."),
        Word(en: "advice", tr: "tavsiye", level: "B1", clue: "An opinion you give someone about what they should do."),
        Word(en: "afford", tr: "parası yetmek", level: "B1", clue: "To have enough money to buy something."),
        Word(en: "agree", tr: "katılmak, aynı fikirde olmak", level: "B1", clue: "To have the same opinion as someone."),
        Word(en: "allow", tr: "izin vermek", level: "B1", clue: "To let someone do something."),
        Word(en: "appointment", tr: "randevu", level: "B1", clue: "A planned time to meet someone, like a doctor."),
        Word(en: "avoid", tr: "kaçınmak", level: "B1", clue: "To stay away from something or someone."),
        Word(en: "behaviour", tr: "davranış", level: "B1", clue: "The way a person acts."),
        Word(en: "challenge", tr: "zorluk, meydan okuma", level: "B1", clue: "Something difficult that tests your ability."),
        Word(en: "complain", tr: "şikayet etmek", level: "B1", clue: "To say that you are not happy about something."),
        Word(en: "confident", tr: "kendinden emin", level: "B1", clue: "Sure about yourself and your abilities."),
        Word(en: "crowded", tr: "kalabalık", level: "B1", clue: "Full of people."),
        Word(en: "damage", tr: "hasar", level: "B1", clue: "Harm that makes something broken or less useful."),
        Word(en: "deliver", tr: "teslim etmek", level: "B1", clue: "To take a letter or package to someone."),
        Word(en: "disappointed", tr: "hayal kırıklığına uğramış", level: "B1", clue: "Sad because something was not as good as you hoped."),
        Word(en: "emergency", tr: "acil durum", level: "B1", clue: "A dangerous situation where you must act quickly."),
        Word(en: "environment", tr: "çevre", level: "B1", clue: "The air, water and land where people, animals and plants live."),
        Word(en: "equipment", tr: "ekipman", level: "B1", clue: "The tools and things you need for a job or activity."),
        Word(en: "experience", tr: "deneyim", level: "B1", clue: "Knowledge or skill you get from doing something."),
        Word(en: "flood", tr: "sel", level: "B1", clue: "A lot of water that covers land that is usually dry."),
        Word(en: "earthquake", tr: "deprem", level: "B1", clue: "When the ground shakes strongly."),
        Word(en: "rescue", tr: "kurtarmak", level: "B1", clue: "To save someone from danger."),
        Word(en: "injured", tr: "yaralı", level: "B1", clue: "Hurt in an accident."),
        Word(en: "improve", tr: "geliştirmek", level: "B1", clue: "To make something better."),
        Word(en: "increase", tr: "artmak, artırmak", level: "B1", clue: "To become bigger in number or amount."),
        Word(en: "reduce", tr: "azaltmak", level: "B1", clue: "To make something smaller or less."),
        Word(en: "knowledge", tr: "bilgi", level: "B1", clue: "What you know and understand."),
        Word(en: "opinion", tr: "fikir, görüş", level: "B1", clue: "What you think about something."),
        Word(en: "patient", tr: "sabırlı", level: "B1", clue: "Able to wait calmly without getting angry."),
        Word(en: "prepare", tr: "hazırlamak", level: "B1", clue: "To get something ready."),
        Word(en: "prevent", tr: "önlemek", level: "B1", clue: "To stop something bad from happening."),
        Word(en: "promise", tr: "söz vermek", level: "B1", clue: "To say that you will surely do something."),
        Word(en: "protect", tr: "korumak", level: "B1", clue: "To keep someone or something safe."),
        Word(en: "recommend", tr: "tavsiye etmek", level: "B1", clue: "To say that something is good and someone should try it."),
        Word(en: "refuse", tr: "reddetmek", level: "B1", clue: "To say no to something."),
        Word(en: "responsible", tr: "sorumlu", level: "B1", clue: "Having the duty to take care of something."),
        Word(en: "schedule", tr: "program, takvim", level: "B1", clue: "A plan that shows when things will happen."),
        Word(en: "solution", tr: "çözüm", level: "B1", clue: "A way to fix a problem."),
        Word(en: "succeed", tr: "başarılı olmak", level: "B1", clue: "To do what you tried to do."),
        Word(en: "suggest", tr: "önermek", level: "B1", clue: "To give an idea for others to think about."),
        Word(en: "support", tr: "desteklemek", level: "B1", clue: "To help someone, often by giving them what they need."),
        Word(en: "survive", tr: "hayatta kalmak", level: "B1", clue: "To stay alive after a dangerous event."),
        Word(en: "warn", tr: "uyarmak", level: "B1", clue: "To tell someone about a possible danger."),
        Word(en: "volunteer", tr: "gönüllü", level: "B1", clue: "A person who works without being paid."),
        Word(en: "shelter", tr: "barınak", level: "B1", clue: "A place that keeps you safe from bad weather or danger."),
        Word(en: "safety", tr: "güvenlik", level: "B1", clue: "Being safe from harm."),
        Word(en: "training", tr: "eğitim", level: "B1", clue: "Learning the skills for a job or a sport."),
        Word(en: "deadline", tr: "son teslim tarihi", level: "B1", clue: "The last day or time to finish something."),
        Word(en: "colleague", tr: "iş arkadaşı", level: "B1", clue: "A person you work with."),
        Word(en: "manager", tr: "yönetici", level: "B1", clue: "A person who controls a team or a business."),
        Word(en: "request", tr: "talep, rica", level: "B1", clue: "When you ask for something politely or officially."),
        Word(en: "arrange", tr: "ayarlamak, düzenlemek", level: "B1", clue: "To plan or organise something."),
        Word(en: "attend", tr: "katılmak (toplantıya)", level: "B1", clue: "To go to an event, a class or a meeting."),
        Word(en: "available", tr: "müsait, mevcut", level: "B1", clue: "Free to use or free to meet."),
        Word(en: "confirm", tr: "onaylamak", level: "B1", clue: "To say that something is true or will happen."),
        Word(en: "delay", tr: "gecikme", level: "B1", clue: "When something happens later than planned."),
        Word(en: "describe", tr: "tarif etmek, anlatmak", level: "B1", clue: "To say what something or someone is like."),
        Word(en: "frightened", tr: "korkmuş", level: "B1", clue: "Feeling afraid."),
        Word(en: "generous", tr: "cömert", level: "B1", clue: "Happy to give money, time or help to others."),
        Word(en: "honest", tr: "dürüst", level: "B1", clue: "Always telling the truth."),
        Word(en: "anxious", tr: "endişeli", level: "B1", clue: "Worried and nervous about something."),
        Word(en: "proud", tr: "gururlu", level: "B1", clue: "Happy about something good you or others did."),
        Word(en: "curious", tr: "meraklı", level: "B1", clue: "Wanting to know or learn about something."),
        Word(en: "grateful", tr: "minnettar", level: "B1", clue: "Feeling thankful."),
        Word(en: "embarrassed", tr: "mahcup, utanmış", level: "B1", clue: "Feeling shy or silly in front of other people."),
        Word(en: "reliable", tr: "güvenilir", level: "B1", clue: "Someone or something you can trust."),
        Word(en: "realise", tr: "farkına varmak", level: "B1", clue: "To suddenly understand or notice something."),
        Word(en: "goal", tr: "hedef", level: "B1", clue: "Something you want to achieve."),
        Word(en: "habit", tr: "alışkanlık", level: "B1", clue: "Something you do often, almost without thinking.")
    ]
}

enum GameMode: String, CaseIterable, Identifiable {
    case meaning = "Anlamı bul"
    case riddle = "Bilmece"
    var id: String { rawValue }
}

enum GameLevel: String, CaseIterable, Identifiable {
    case a2 = "A2"
    case b1 = "B1"
    case mixed = "Karışık"
    var id: String { rawValue }
}

@Observable
final class WordGame {
    var level: GameLevel = .mixed
    var mode: GameMode = .meaning
    var current: Word = WordBank.all[0]
    var options: [String] = []
    var picked: String?
    var guess = ""
    var lettersShown = 1
    var showTurkish = false
    var riddleSolved: Bool?
    var score = 0
    var streak = 0
    var best = UserDefaults.standard.integer(forKey: "wordBest")
    private var recent: [String] = []

    init() { next() }

    private var pool: [Word] {
        switch level {
        case .a2: return WordBank.a2
        case .b1: return WordBank.b1
        case .mixed: return WordBank.all
        }
    }

    func next() {
        let candidates = pool.filter { !recent.contains($0.en) }
        current = (candidates.isEmpty ? pool : candidates).randomElement() ?? WordBank.all[0]
        recent.append(current.en)
        if recent.count > 15 { recent.removeFirst() }
        let others = pool.filter { $0.en != current.en }.shuffled().prefix(3).map(\.tr)
        options = (others + [current.tr]).shuffled()
        picked = nil
        guess = ""
        lettersShown = 1
        showTurkish = false
        riddleSolved = nil
    }

    private func record(_ correct: Bool) {
        if correct {
            score += 1
            streak += 1
            if streak > best {
                best = streak
                UserDefaults.standard.set(best, forKey: "wordBest")
            }
        } else {
            streak = 0
        }
    }

    func pick(_ option: String) {
        guard picked == nil else { return }
        picked = option
        record(option == current.tr)
    }

    func check() {
        guard riddleSolved == nil else { return }
        let g = guess.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !g.isEmpty else { return }
        if g == current.en.lowercased() {
            riddleSolved = true
            record(true)
        }
    }

    func giveUp() {
        guard riddleSolved == nil else { return }
        riddleSolved = false
        record(false)
    }

    func hintLetter() {
        if lettersShown < current.en.count - 1 { lettersShown += 1 }
    }

    var pattern: String {
        current.en.enumerated().map { i, c in i < lettersShown ? String(c).uppercased() : "_" }.joined(separator: " ")
    }
}

struct WordGameView: View {
    @State private var game = WordGame()
    @FocusState private var answerFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("Mod", selection: $game.mode) {
                    ForEach(GameMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Seviye", selection: $game.level) {
                    ForEach(GameLevel.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    stat("Puan", "\(game.score)")
                    stat("Seri", "\(game.streak)")
                    stat("En iyi seri", "\(game.best)")
                }

                if game.mode == .meaning {
                    meaningCard
                } else {
                    riddleCard
                }
            }
            .padding()
        }
        .navigationTitle("Kelime oyunu")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: game.level) { _, _ in game.next() }
        .onChange(of: game.mode) { _, _ in game.next() }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.weight(.bold).monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var levelBadge: some View {
        Text(game.current.level)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.loz.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.loz)
    }

    private var meaningCard: some View {
        VStack(spacing: 16) {
            levelBadge
            Text(game.current.en)
                .font(.system(size: 38, weight: .bold, design: .rounded))
            Text(game.current.clue)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                ForEach(game.options, id: \.self) { option in
                    Button {
                        withAnimation(.snappy) { game.pick(option) }
                    } label: {
                        HStack {
                            Text(option)
                            Spacer()
                            if let picked = game.picked {
                                if option == game.current.tr {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else if option == picked {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                }
                            }
                        }
                        .padding()
                        .background(optionColor(option), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(game.picked != nil)
                }
            }
            if game.picked != nil {
                Text(game.picked == game.current.tr ? "Doğru!" : "Doğrusu: \(game.current.tr)")
                    .font(.headline)
                    .foregroundStyle(game.picked == game.current.tr ? Color.green : Color.red)
                nextButton
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08)))
    }

    private func optionColor(_ option: String) -> Color {
        guard let picked = game.picked else { return Color(.secondarySystemBackground) }
        if option == game.current.tr { return Color.green.opacity(0.18) }
        if option == picked { return Color.red.opacity(0.18) }
        return Color(.secondarySystemBackground)
    }

    private var riddleCard: some View {
        VStack(spacing: 16) {
            levelBadge
            Text(game.current.clue)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(game.riddleSolved == nil ? game.pattern : game.current.en.uppercased())
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundStyle(game.riddleSolved == false ? Color.red : Color.loz)
                .multilineTextAlignment(.center)
            Text("\(game.current.en.count) harf")
                .font(.caption)
                .foregroundStyle(.secondary)
            if game.showTurkish || game.riddleSolved != nil {
                Text("Türkçesi: \(game.current.tr)")
                    .foregroundStyle(.secondary)
            }
            if game.riddleSolved == nil {
                TextField("Cevabını yaz", text: $game.guess)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($answerFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        game.check()
                        if game.riddleSolved == nil { answerFocused = true }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                HStack(spacing: 10) {
                    Button("Kontrol et") { game.check() }
                        .buttonStyle(.borderedProminent)
                    Button("Harf ver") { game.hintLetter() }
                        .buttonStyle(.bordered)
                    Button("Türkçesi") { game.showTurkish = true }
                        .buttonStyle(.bordered)
                        .disabled(game.showTurkish)
                }
                .controlSize(.regular)
                if !game.guess.isEmpty && game.guess.count >= game.current.en.count && game.riddleSolved == nil {
                    Text("Henüz değil, tekrar dene.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Pes et", role: .destructive) { game.giveUp() }
                    .font(.footnote)
            } else {
                Text(game.riddleSolved == true ? "Bildin!" : "Cevap: \(game.current.en)")
                    .font(.headline)
                    .foregroundStyle(game.riddleSolved == true ? Color.green : Color.red)
                nextButton
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08)))
    }

    private var nextButton: some View {
        Button {
            withAnimation(.snappy) { game.next() }
            if game.mode == .riddle { answerFocused = true }
        } label: {
            Text("Sonraki kelime").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}
