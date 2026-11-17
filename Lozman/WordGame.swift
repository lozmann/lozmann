import SwiftUI
import Observation
import AVFoundation
import UIKit

// MARK: - Words

struct Word: Codable, Hashable {
    let en: String
    let tr: String
    let level: String
    let clue: String
    let ex: String
}

enum WordBank {
    static let all: [Word] = {
        if let url = Bundle.main.url(forResource: "words", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let words = try? JSONDecoder().decode([Word].self, from: data),
           !words.isEmpty {
            return words
        }
        return [Word(en: "goal", tr: "hedef", level: "B1", clue: "Something you want to achieve.", ex: "My goal is to speak English well.")]
    }()

    static var a2: [Word] { all.filter { $0.level == "A2" } }
    static var b1: [Word] { all.filter { $0.level == "B1" } }
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

    static func say(_ text: String) {
        activate()
        speaker.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = 0.45
        speaker.speak(u)
    }

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
}

enum GameMode: String, CaseIterable, Identifiable {
    case meaning = "İng → Tr"
    case reverse = "Tr → İng"
    case riddle = "Bilmece"
    case mistakes = "Hatalarım"
    var id: String { rawValue }
}

enum GameLevel: String, CaseIterable, Identifiable {
    case a2 = "A2"
    case b1 = "B1"
    case mixed = "Karışık"
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

    var level: GameLevel = .mixed
    var mode: GameMode = .meaning
    var current: Word = WordBank.all[0]
    var options: [Word] = []
    var picked: Word?
    var guess = ""
    var lettersShown = 1
    var showTurkish = false
    var showSentence = false
    var riddleSolved: Bool?
    var combo = 0
    var progress = GameProgress()
    var reward: Reward?
    var confetti = 0
    private var recent: [String] = []

    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("words-progress.json")

    init() {
        if let data = try? Data(contentsOf: url),
           let p = try? JSONDecoder().decode(GameProgress.self, from: data) {
            progress = p
        }
        progress.bestCombo = max(progress.bestCombo, UserDefaults.standard.integer(forKey: "wordBest"))
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

    private var pool: [Word] {
        if mode == .mistakes {
            let set = Set(progress.mistakes)
            return WordBank.all.filter { set.contains($0.en) }
        }
        switch level {
        case .a2: return WordBank.a2
        case .b1: return WordBank.b1
        case .mixed: return WordBank.all
        }
    }

    var mistakesEmpty: Bool { mode == .mistakes && progress.mistakes.isEmpty }

    func next() {
        let p = pool
        guard !p.isEmpty else { return }
        // Words you got wrong before come up a little more often.
        let fresh = p.filter { !recent.contains($0.en) }
        let source = fresh.isEmpty ? p : fresh
        let weighted = source.flatMap { w -> [Word] in
            (progress.stats[w.en]?.wrong ?? 0) > (progress.stats[w.en]?.right ?? 0) ? [w, w, w] : [w]
        }
        current = weighted.randomElement() ?? p[0]
        recent.append(current.en)
        if recent.count > 20 { recent.removeFirst() }
        let distractorPool = WordBank.all.filter { $0.en != current.en && $0.level == current.level && $0.tr != current.tr }
        options = (Array(distractorPool.shuffled().prefix(3)) + [current]).shuffled()
        picked = nil
        guess = ""
        lettersShown = 1
        showTurkish = false
        showSentence = false
        riddleSolved = nil
    }

    private func record(_ correct: Bool) {
        var stat = progress.stats[current.en] ?? WordStat()
        if correct {
            stat.right += 1
            combo += 1
            let levelBefore = playerLevel
            let todayBefore = todayCount
            let bonus = combo >= 10 ? 15 : (combo >= 5 ? 10 : (combo >= 3 ? 5 : 0))
            let gained = 10 + bonus
            progress.xp += gained
            progress.daily[Day.today] = todayBefore + 1
            progress.bestCombo = max(progress.bestCombo, combo)
            if mode == .mistakes { progress.mistakes.removeAll { $0 == current.en } }

            if playerLevel > levelBefore {
                reward = Reward(text: "Seviye \(playerLevel)!", big: true)
                confetti += 1
                Sfx.play("levelup")
            } else if todayBefore + 1 == Self.dailyGoal {
                reward = Reward(text: "Günlük hedef tamam!", big: true)
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
        if g == current.en.lowercased() {
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

    var pattern: String {
        var shown = 0
        return current.en.map { c -> String in
            if c == " " { return "  " }
            shown += 1
            return shown <= lettersShown ? String(c).uppercased() : "_"
        }.joined(separator: " ")
    }

    /// The example sentence with the word hidden, as an extra hint.
    var hiddenSentence: String {
        let lower = current.ex.lowercased()
        let key = current.en.lowercased()
        guard let range = lower.range(of: key) else { return current.ex }
        let start = current.ex.index(current.ex.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))
        let end = current.ex.index(start, offsetBy: key.count)
        return current.ex.replacingCharacters(in: start..<end, with: String(repeating: "_", count: key.count))
    }
}

// MARK: - Views

struct WordGameView: View {
    @State private var game = WordGame()
    @State private var soundOn = Sfx.soundOn
    @FocusState private var answerFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                Picker("Mod", selection: $game.mode) {
                    ForEach(GameMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if game.mode != .mistakes {
                    Picker("Seviye", selection: $game.level) {
                        ForEach(GameLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if game.mistakesEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(.green)
                        Text("Hata listen boş").font(.headline)
                        Text("Yanlış yaptığın kelimeler burada birikir. Doğru bildiğinde listeden çıkar.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(30)
                } else {
                    switch game.mode {
                    case .meaning, .mistakes: choiceCard(reverse: false)
                    case .reverse: choiceCard(reverse: true)
                    case .riddle: riddleCard
                    }
                }
            }
            .padding()
        }
        .overlay(alignment: .top) { rewardBanner }
        .overlay { ConfettiView(trigger: game.confetti).allowsHitTesting(false) }
        .navigationTitle("Kelime oyunu")
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
        .onChange(of: game.level) { _, _ in game.combo = 0; game.next() }
        .onChange(of: game.mode) { _, _ in game.combo = 0; game.next() }
    }

    // Level, XP, daily goal, streaks
    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.loz.opacity(0.18), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: min(1, Double(game.todayCount) / Double(WordGame.dailyGoal)))
                        .stroke(Color.loz, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.snappy, value: game.todayCount)
                    VStack(spacing: 0) {
                        Text("\(game.todayCount)").font(.headline.monospacedDigit())
                        Text("/\(WordGame.dailyGoal)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 62, height: 62)
                .accessibilityLabel("Bugün \(game.todayCount) doğru, hedef \(WordGame.dailyGoal)")

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Seviye \(game.playerLevel)").font(.headline)
                        Spacer()
                        Text("\(game.progress.xp) XP").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    ProgressView(value: game.levelProgress).tint(.loz)
                        .animation(.snappy, value: game.progress.xp)
                    Text("Sonraki seviyeye \(game.xpToNext) XP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                chip(icon: "flame.fill", value: "\(game.combo)", label: "Kombo", tint: game.combo >= 3 ? .orange : .secondary)
                chip(icon: "calendar", value: "\(game.dayStreak)", label: "Gün serisi", tint: .loz)
                chip(icon: "trophy.fill", value: "\(game.progress.bestCombo)", label: "En iyi kombo", tint: .yellow)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func chip(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(value).font(.headline.monospacedDigit())
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var levelBadge: some View {
        HStack(spacing: 8) {
            Text(game.current.level)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.loz.opacity(0.15), in: Capsule())
                .foregroundStyle(Color.loz)
            if game.mode == .mistakes {
                Text("\(game.progress.mistakes.count) hatalı kelime")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    private func choiceCard(reverse: Bool) -> some View {
        VStack(spacing: 16) {
            levelBadge
            HStack(spacing: 10) {
                Text(reverse ? game.current.tr : game.current.en)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                if !reverse { speakButton(game.current.en) }
            }
            if !reverse {
                Text(game.current.clue)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
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
                        .padding()
                        .background(optionColor(option), in: RoundedRectangle(cornerRadius: 12))
                        .scaleEffect(game.picked?.en == option.en && option.en == game.current.en ? 1.03 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(game.picked != nil)
                }
            }
            if let picked = game.picked {
                answerFooter(correct: picked.en == game.current.en)
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08)))
    }

    private func answerFooter(correct: Bool) -> some View {
        VStack(spacing: 10) {
            Text(correct ? "Doğru!" : "Doğrusu: \(game.current.en) = \(game.current.tr)")
                .font(.headline)
                .foregroundStyle(correct ? Color.green : Color.red)
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
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            nextButton
        }
    }

    private func optionColor(_ option: Word) -> Color {
        guard let picked = game.picked else { return Color(.secondarySystemBackground) }
        if option.en == game.current.en { return Color.green.opacity(0.18) }
        if option.en == picked.en { return Color.red.opacity(0.18) }
        return Color(.secondarySystemBackground)
    }

    private var riddleCard: some View {
        VStack(spacing: 14) {
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
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.08)))
    }

    private var nextButton: some View {
        Button {
            withAnimation(.snappy) {
                game.reward = nil
                game.next()
            }
            if game.mode == .riddle { answerFocused = true }
        } label: {
            Text("Sonraki kelime").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
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
