import SwiftUI
import Observation
import AVFoundation
import UIKit

// MARK: - Words

struct Word: Codable, Hashable {
    let en: String
    let tr: String
    let level: String
    let cat: String?
    let clue: String
    let ex: String

    var category: String { cat ?? "Genel" }
}

enum WordBank {
    static let all: [Word] = {
        if let url = Bundle.main.url(forResource: "words", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let words = try? JSONDecoder().decode([Word].self, from: data),
           !words.isEmpty {
            return words.filter { $0.level != "A2" }
        }
        return [Word(en: "goal", tr: "hedef", level: "B1", cat: "Genel", clue: "Something you want to achieve.", ex: "My goal is to speak English well.")]
    }()

    /// Categories in the order they appear in the file.
    static let categories: [String] = {
        var seen: [String] = []
        for w in all where !seen.contains(w.category) { seen.append(w.category) }
        return seen
    }()

    static func icon(for cat: String) -> String {
        switch cat {
        case "Su kurtarma": return "water.waves"
        case "Arama kurtarma & AFAD": return "light.beacon.max.fill"
        case "Meslekler": return "person.2.fill"
        case "Günlük hayat": return "house.fill"
        case "Sağlık": return "cross.case.fill"
        case "İş & ofis": return "briefcase.fill"
        case "Seyahat": return "airplane"
        case "Duygular & karakter": return "face.smiling"
        case "Doğa & hava": return "cloud.sun.fill"
        case "Teknoloji": return "iphone"
        case "Para & alışveriş": return "cart.fill"
        case "Phrasal verbs": return "arrow.triangle.branch"
        case "Sohbet kalıpları": return "bubble.left.and.bubble.right.fill"
        default: return "book.fill"
        }
    }
}

// MARK: - Sound, haptics, speech

enum Sfx {
    private static var players: [String: AVAudioPlayer] = [:]
    private static let speaker = AVSpeechSynthesizer()

    static var soundOn: Bool {
        get { UserDefaults.standard.object(forKey: "gameSound") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "gameSound") }
    }

    private static func activate() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    static func play(_ name: String) {
        guard soundOn else { return }
        activate()
        if players[name] == nil, let url = Bundle.main.url(forResource: name, withExtension: "wav") {
            players[name] = try? AVAudioPlayer(contentsOf: url)
            players[name]?.prepareToPlay()
        }
        players[name]?.currentTime = 0
        players[name]?.play()
    }

    static func preview(_ name: String) {
        activate()
        if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
            players[name] = try? AVAudioPlayer(contentsOf: url)
            players[name]?.play()
        }
    }

    static func say(_ text: String, slow: Bool = false) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        speaker.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = slow ? 0.36 : 0.47
        speaker.speak(u)
    }

    static func stopSpeaking() { speaker.stopSpeaking(at: .immediate) }

    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func bump() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
}

// MARK: - Progress

struct WordStat: Codable {
    var right = 0
    var wrong = 0
}

struct GameProgress: Codable {
    var xp = 0
    var bestCombo = 0
    var daily: [String: Int] = [:]
    var stats: [String: WordStat] = [:]
    var mistakes: [String] = []
    /// Spaced repetition: box 1...6 and the day the word is due again.
    var box: [String: Int] = [:]
    var due: [String: String] = [:]
    /// New words started per day in the daily review.
    var introduced: [String: Int] = [:]
    var spoken: [String: Int] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        bestCombo = try c.decodeIfPresent(Int.self, forKey: .bestCombo) ?? 0
        daily = try c.decodeIfPresent([String: Int].self, forKey: .daily) ?? [:]
        stats = try c.decodeIfPresent([String: WordStat].self, forKey: .stats) ?? [:]
        mistakes = try c.decodeIfPresent([String].self, forKey: .mistakes) ?? []
        box = try c.decodeIfPresent([String: Int].self, forKey: .box) ?? [:]
        due = try c.decodeIfPresent([String: String].self, forKey: .due) ?? [:]
        introduced = try c.decodeIfPresent([String: Int].self, forKey: .introduced) ?? [:]
        spoken = try c.decodeIfPresent([String: Int].self, forKey: .spoken) ?? [:]
    }
}

enum GameMode: String, CaseIterable, Identifiable {
    case review = "Günün tekrarı"
    case speak = "Söyle"
    case build = "Cümle kur"
    case reverse = "Tr → İng"
    case meaning = "İng → Tr"
    case sentence = "Boşluk doldur"
    case riddle = "Bilmece"
    case mistakes = "Hatalarım"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .review: return "repeat.circle.fill"
        case .speak: return "mic.fill"
        case .build: return "text.bubble.fill"
        case .reverse: return "arrow.left.arrow.right"
        case .meaning: return "character.book.closed"
        case .sentence: return "text.quote"
        case .riddle: return "puzzlepiece"
        case .mistakes: return "arrow.counterclockwise"
        }
    }
    var help: String {
        switch self {
        case .review: return "Unutmak üzere olduğun kelimeler ve günde 10 yeni kelime. Her gün 5 dakika."
        case .speak: return "Türkçesini gör, İngilizcesini sesli söyle. Kelimeyi aklından çekip çıkarmak konuşmanın ta kendisi."
        case .build: return "Kelimeyi kullanarak sesli bir cümle kur."
        case .reverse: return "Türkçeden İngilizceye: konuşurken beynin bu yönde çalışır."
        case .meaning: return "İngilizce kelimenin anlamını seç."
        case .sentence: return "Cümledeki boşluğa doğru kelimeyi seç."
        case .riddle: return "İngilizce tarifi oku, kelimeyi yaz."
        case .mistakes: return "Yanlış yaptığın kelimeler."
        }
    }
}

enum GameLevel: String, CaseIterable, Identifiable {
    case b1 = "B1"
    case b2 = "B2"
    case mixed = "B1 + B2"
    var id: String { rawValue }
}

struct Reward: Equatable {
    var id = UUID()
    var text: String
    var big: Bool
}

@Observable
final class WordGame {
    static let dailyGoal = 20
    static let newPerDay = 10
    static let intervals = [0, 1, 2, 4, 7, 15, 30]
    static let allCategories = "Tümü"

    var level: GameLevel = .mixed
    var mode: GameMode = .review
    var category = WordGame.allCategories
    var current: Word = WordBank.all[0]
    var options: [Word] = []
    var picked: Word?
    var guess = ""
    var lettersShown = 1
    var showTurkish = false
    var showSentence = false
    var riddleSolved: Bool?
    var spoken: Bool?
    var heard = ""
    var speakHint = 0
    var built: Bool?
    var builtSentence = ""
    var coachNote: String?
    var coachBusy = false
    var combo = 0
    var progress = GameProgress()
    var reward: Reward?
    var confetti = 0
    var empty = false
    private var recent: [String] = []

    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("words-progress.json")

    init() {
        if let data = try? Data(contentsOf: url),
           let p = try? JSONDecoder().decode(GameProgress.self, from: data) {
            progress = p
        }
        progress.bestCombo = max(progress.bestCombo, UserDefaults.standard.integer(forKey: "wordBest"))
        if let saved = UserDefaults.standard.string(forKey: "wordCategory"), WordBank.categories.contains(saved) {
            category = saved
        }
        next()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(progress) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // Levels: each level needs a bit more XP than the one before.
    static func xpFor(level n: Int) -> Int { 50 * n * (n - 1) }
    var playerLevel: Int {
        var n = 1
        while progress.xp >= Self.xpFor(level: n + 1) { n += 1 }
        return n
    }
    var levelProgress: Double {
        let lo = Self.xpFor(level: playerLevel), hi = Self.xpFor(level: playerLevel + 1)
        return Double(progress.xp - lo) / Double(max(1, hi - lo))
    }
    var xpToNext: Int { Self.xpFor(level: playerLevel + 1) - progress.xp }

    var todayCount: Int { progress.daily[Day.today] ?? 0 }

    var dayStreak: Int {
        var n = 0
        var day = Day.today
        if (progress.daily[day] ?? 0) == 0 { day = Day.add(day, -1) }
        while (progress.daily[day] ?? 0) > 0 {
            n += 1
            day = Day.add(day, -1)
        }
        return n
    }

    var learnedCount: Int { progress.box.values.filter { $0 >= 4 }.count }

    var answered: Bool {
        switch mode {
        case .speak: return spoken != nil
        case .build: return built != nil
        case .riddle: return riddleSolved != nil
        default: return picked != nil
        }
    }

    var lastAnswerCorrect: Bool {
        switch mode {
        case .speak: return spoken == true
        case .build: return built == true
        case .riddle: return riddleSolved == true
        default: return picked?.en == current.en
        }
    }

    // MARK: Pools

    private var filtered: [Word] {
        var base: [Word]
        switch level {
        case .b1: base = WordBank.all.filter { $0.level == "B1" }
        case .b2: base = WordBank.all.filter { $0.level == "B2" }
        case .mixed: base = WordBank.all
        }
        if category != Self.allCategories { base = base.filter { $0.category == category } }
        return base
    }

    var dueWords: [Word] {
        let today = Day.today
        return filtered.filter { w in
            guard let d = progress.due[w.en] else { return false }
            return d <= today
        }
    }

    var newLeftToday: Int { max(0, Self.newPerDay - (progress.introduced[Day.today] ?? 0)) }

    private var newWords: [Word] { filtered.filter { progress.box[$0.en] == nil } }

    var reviewLeft: Int { dueWords.count + min(newLeftToday, newWords.count) }

    private var pool: [Word] {
        switch mode {
        case .mistakes:
            let set = Set(progress.mistakes)
            return WordBank.all.filter { set.contains($0.en) }
        case .review:
            let due = dueWords
            if !due.isEmpty { return due }
            return newLeftToday > 0 ? Array(newWords.prefix(40)) : []
        case .sentence:
            return filtered.filter { $0.ex.lowercased().contains($0.en.lowercased()) }
        default:
            return filtered
        }
    }

    var mistakesEmpty: Bool { mode == .mistakes && progress.mistakes.isEmpty }

    func next() {
        let p = pool
        empty = p.isEmpty
        picked = nil
        guess = ""
        lettersShown = 1
        showTurkish = false
        showSentence = false
        riddleSolved = nil
        spoken = nil
        heard = ""
        speakHint = 0
        built = nil
        builtSentence = ""
        coachNote = nil
        coachBusy = false
        guard !p.isEmpty else { return }
        // Words you got wrong before come up a little more often.
        let fresh = p.filter { !recent.contains($0.en) }
        let source = fresh.isEmpty ? p : fresh
        let weighted = source.flatMap { w -> [Word] in
            (progress.stats[w.en]?.wrong ?? 0) > (progress.stats[w.en]?.right ?? 0) ? [w, w, w] : [w]
        }
        current = weighted.randomElement() ?? p[0]
        recent.append(current.en)
        if recent.count > min(25, max(1, p.count - 1)) { recent.removeFirst() }
        // Wrong options from the same topic make you think harder.
        let sameCat = WordBank.all.filter { $0.en != current.en && $0.category == current.category && $0.tr != current.tr }
        let sameLevel = WordBank.all.filter { $0.en != current.en && $0.level == current.level && $0.tr != current.tr }
        let distractors = sameCat.count >= 3 ? sameCat : sameLevel
        options = (Array(distractors.shuffled().prefix(3)) + [current]).shuffled()
    }

    // MARK: Scoring

    private func record(_ correct: Bool, xp base: Int = 10) {
        var stat = progress.stats[current.en] ?? WordStat()
        let today = Day.today
        if progress.box[current.en] == nil && mode == .review {
            progress.introduced[today, default: 0] += 1
        }
        let oldBox = progress.box[current.en] ?? 0
        let newBox = correct ? min(6, oldBox + 1) : 1
        progress.box[current.en] = newBox
        progress.due[current.en] = correct ? Day.add(today, Self.intervals[newBox]) : today

        if correct {
            stat.right += 1
            combo += 1
            let levelBefore = playerLevel
            let todayBefore = todayCount
            let bonus = combo >= 10 ? 15 : (combo >= 5 ? 10 : (combo >= 3 ? 5 : 0))
            let gained = base + bonus
            progress.xp += gained
            progress.daily[today] = todayBefore + 1
            progress.bestCombo = max(progress.bestCombo, combo)
            progress.mistakes.removeAll { $0 == current.en && mode == .mistakes }

            if playerLevel > levelBefore {
                reward = Reward(text: "Seviye \(playerLevel)!", big: true)
                confetti += 1
                Sfx.play("levelup")
            } else if todayBefore + 1 == Self.dailyGoal {
                reward = Reward(text: "Günlük hedef tamam!", big: true)
                confetti += 1
                Sfx.play("levelup")
            } else if mode == .review && reviewLeft == 0 {
                reward = Reward(text: "Günün tekrarı bitti!", big: true)
                confetti += 1
                Sfx.play("levelup")
            } else if combo > 0 && combo % 5 == 0 {
                reward = Reward(text: "\(combo) kombo! +\(gained) XP", big: true)
                confetti += 1
                Sfx.play("combo")
            } else {
                reward = Reward(text: bonus > 0 ? "+\(gained) XP · kombo x\(combo)" : "+\(gained) XP", big: false)
                Sfx.play("correct")
            }
            Sfx.success()
        } else {
            stat.wrong += 1
            combo = 0
            if !progress.mistakes.contains(current.en) { progress.mistakes.append(current.en) }
            reward = nil
            Sfx.play("wrong")
            Sfx.failure()
        }
        progress.stats[current.en] = stat
        save()
    }

    func pick(_ option: Word) {
        guard picked == nil else { return }
        picked = option
        record(option.en == current.en)
    }

    @discardableResult
    func check() -> Bool {
        guard riddleSolved == nil else { return false }
        let g = guess.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !g.isEmpty else { return false }
        if g == current.en.lowercased() || SpeechListener.normalize(g) == SpeechListener.normalize(current.en) {
            riddleSolved = true
            record(true)
            return true
        }
        Sfx.bump()
        return false
    }

    func giveUp() {
        guard riddleSolved == nil else { return }
        riddleSolved = false
        record(false)
    }

    func hintLetter() {
        let letters = current.en.filter { $0 != " " }.count
        if lettersShown < letters - 1 { lettersShown += 1 }
    }

    // MARK: Speaking

    /// Checks what the microphone heard against the target word.
    func checkSpoken(_ text: String) {
        guard spoken == nil else { return }
        heard = text
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if SpeechListener.heard(current.en, in: text) {
            spoken = true
            progress.spoken[current.en, default: 0] += 1
            record(true, xp: speakHint == 0 ? 15 : 10)
            Sfx.say(current.en)
        } else {
            Sfx.bump()
        }
    }

    func revealSpoken() {
        guard spoken == nil else { return }
        spoken = false
        record(false)
        Sfx.say(current.en)
    }

    /// "Cümle kur": a spoken or typed sentence that uses the word.
    func checkBuilt(_ text: String) {
        guard built == nil else { return }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        builtSentence = clean
        guard !clean.isEmpty else { return }
        let words = clean.split(separator: " ").count
        if SpeechListener.heard(current.en, in: clean) && words >= 4 {
            built = true
            progress.spoken[current.en, default: 0] += 1
            record(true, xp: 20)
        } else {
            Sfx.bump()
        }
    }

    func skipBuilt() {
        guard built == nil else { return }
        built = false
        record(false)
    }

    /// Asks the AI to correct the sentence, if a key is set.
    @MainActor
    func askCoach() async {
        guard !builtSentence.isEmpty, !coachBusy else { return }
        coachBusy = true
        defer { coachBusy = false }
        let system = """
        You are an English teacher for a Turkish B1 learner. The student had to make a sentence with the word "\(current.en)". \
        Reply in at most 3 short lines: 1) The corrected sentence in natural English (or "Perfect!" if it is already correct). \
        2) One very short explanation in Turkish. 3) One more natural example with the word. No other text.
        """
        do {
            coachNote = try await CoachAI.reply(system: system, history: [ChatMessage(fromUser: true, text: builtSentence)]) { [weak self] t in
                self?.coachNote = t
            }
        } catch {
            coachNote = error.localizedDescription
        }
    }

    var pattern: String {
        var shown = 0
        return current.en.map { c -> String in
            if c == " " { return "  " }
            shown += 1
            return shown <= lettersShown ? String(c).uppercased() : "_"
        }.joined(separator: " ")
    }

    var speakPattern: String {
        var shown = 0
        return current.en.map { c -> String in
            if c == " " { return "  " }
            if !c.isLetter { return String(c) }
            shown += 1
            return shown <= speakHint ? String(c).uppercased() : "_"
        }.joined(separator: " ")
    }

    /// The example sentence with the word hidden, as an extra hint.
    var hiddenSentence: String {
        let lower = current.ex.lowercased()
        let key = current.en.lowercased()
        guard let range = lower.range(of: key) else { return current.ex }
        let start = current.ex.index(current.ex.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))
        var end = current.ex.index(start, offsetBy: key.count)
        while end < current.ex.endIndex, current.ex[end].isLetter { end = current.ex.index(after: end) }
        return current.ex.replacingCharacters(in: start..<end, with: "_____")
    }
}

/// A short burst of colourful pieces from the top of the screen.
struct ConfettiView: View {
    let trigger: Int
    @State private var pieces: [Piece] = []
    @State private var fallen = false

    struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let drift: CGFloat
        let size: CGFloat
        let color: Color
        let spin: Double
        let delay: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 1.6)
                        .rotationEffect(.degrees(fallen ? p.spin : 0))
                        .position(x: p.x * geo.size.width + (fallen ? p.drift : 0),
                                  y: fallen ? geo.size.height + 40 : -20)
                        .opacity(fallen ? 0 : 1)
                        .animation(.easeIn(duration: 1.6).delay(p.delay), value: fallen)
                }
            }
        }
        .onChange(of: trigger) { _, _ in
            let colors: [Color] = [.loz, .yellow, .pink, .green, .blue, .purple]
            pieces = (0..<40).map { _ in
                Piece(x: .random(in: 0.05...0.95), drift: .random(in: -80...80), size: .random(in: 6...11),
                      color: colors.randomElement() ?? .loz, spin: .random(in: 180...720), delay: .random(in: 0...0.3))
            }
            fallen = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { fallen = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { pieces = [] }
        }
    }
}
