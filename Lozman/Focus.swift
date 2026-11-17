import SwiftUI
import Observation
import UserNotifications
import UIKit

@Observable
final class FocusStore {
    static let shared = FocusStore()

    enum Kind: String { case focus, rest }

    var minutesByDay: [String: Int] = [:]
    var sessions = 0
    var endDate: Date?
    var pausedRemaining: TimeInterval?
    var kind: Kind = .focus
    var length: Int = 25          // minutes of the current block
    var focusLength = 25
    var restLength = 5
    var finished = 0              // bumps when a block completes, for rewards

    private let d = UserDefaults.standard

    private init() {
        minutesByDay = (d.dictionary(forKey: "focusMinutes") as? [String: Int]) ?? [:]
        sessions = d.integer(forKey: "focusSessions")
        focusLength = d.object(forKey: "focusLength") as? Int ?? 25
        restLength = d.object(forKey: "restLength") as? Int ?? 5
        length = focusLength
        if let end = d.object(forKey: "focusEnd") as? Date, end > Date() {
            endDate = end
            kind = Kind(rawValue: d.string(forKey: "focusKind") ?? "focus") ?? .focus
            length = d.object(forKey: "focusBlock") as? Int ?? focusLength
        }
    }

    func replaceMinutes(_ m: [String: Int]) {
        minutesByDay = m
        d.set(m, forKey: "focusMinutes")
    }

    var running: Bool { endDate != nil }
    var today: Int { minutesByDay[Day.today] ?? 0 }

    var week: Int {
        (0..<7).reduce(0) { $0 + (minutesByDay[Day.add(Day.today, -$1)] ?? 0) }
    }

    func remaining(at now: Date) -> TimeInterval {
        if let end = endDate { return max(0, end.timeIntervalSince(now)) }
        if let p = pausedRemaining { return p }
        return TimeInterval(length * 60)
    }

    func start() {
        let secs = pausedRemaining ?? TimeInterval(length * 60)
        pausedRemaining = nil
        endDate = Date().addingTimeInterval(secs)
        persist()
        scheduleEnd()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func pause() {
        guard let end = endDate else { return }
        pausedRemaining = max(0, end.timeIntervalSinceNow)
        endDate = nil
        persist()
        cancelEnd()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func reset(to newKind: Kind? = nil) {
        if let newKind { kind = newKind }
        length = kind == .focus ? focusLength : restLength
        endDate = nil
        pausedRemaining = nil
        persist()
        cancelEnd()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func setLengths(focus: Int, rest: Int) {
        focusLength = focus
        restLength = rest
        d.set(focus, forKey: "focusLength")
        d.set(rest, forKey: "restLength")
        if !running && pausedRemaining == nil { length = kind == .focus ? focus : rest }
    }

    /// Called every tick; finishes the block once time is up.
    func check(_ now: Date) {
        guard let end = endDate, now >= end else { return }
        endDate = nil
        UIApplication.shared.isIdleTimerDisabled = false
        if kind == .focus {
            minutesByDay[Day.today, default: 0] += length
            sessions += 1
            d.set(minutesByDay, forKey: "focusMinutes")
            d.set(sessions, forKey: "focusSessions")
            finished += 1
            Sfx.play(sessions % 4 == 0 ? "levelup" : "combo")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            reset(to: .rest)
        } else {
            Sfx.play("correct")
            reset(to: .focus)
        }
        persist()
    }

    private func persist() {
        d.set(endDate, forKey: "focusEnd")
        d.set(kind.rawValue, forKey: "focusKind")
        d.set(length, forKey: "focusBlock")
    }

    private func scheduleEnd() {
        guard let end = endDate else { return }
        let c = UNMutableNotificationContent()
        c.title = kind == .focus ? "Odak süresi bitti" : "Mola bitti"
        c.body = kind == .focus ? "Harika iş! \(length) dakika odaklandın. Şimdi kısa bir mola." : "Hazırsan yeni bir odak bloğuna başla."
        c.sound = Notifier.currentSound
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "focus|end", content: c, trigger: trigger))
    }

    private func cancelEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus|end"])
    }
}

struct FocusView: View {
    @Environment(FocusStore.self) private var focus
    @State private var confetti = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { tl in
            let rem = focus.remaining(at: tl.date)
            let total = TimeInterval(focus.length * 60)
            let progress = total > 0 ? 1 - rem / total : 0
            ScrollView {
                VStack(spacing: 26) {
                    Picker("Tür", selection: Binding(get: { focus.kind }, set: { focus.reset(to: $0) })) {
                        Text("Odak").tag(FocusStore.Kind.focus)
                        Text("Mola").tag(FocusStore.Kind.rest)
                    }
                    .pickerStyle(.segmented)
                    .disabled(focus.running)

                    ZStack {
                        Circle().stroke(Color.loz.opacity(0.15), lineWidth: 18)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(focus.kind == .focus ? Color.loz : Color.green,
                                    style: StrokeStyle(lineWidth: 18, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: progress)
                        VStack(spacing: 6) {
                            Text(timeText(rem))
                                .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                                .contentTransition(.numericText())
                            Text(focus.kind == .focus ? (focus.running ? "Odaklan" : "Hazır") : "Mola")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 270, height: 270)

                    HStack(spacing: 16) {
                        Button {
                            focus.reset()
                        } label: {
                            Image(systemName: "arrow.counterclockwise").font(.title2).frame(width: 60, height: 60)
                        }
                        .buttonStyle(.bordered)
                        .clipShape(Circle())
                        .accessibilityLabel("Sıfırla")

                        Button {
                            if focus.running { focus.pause() } else { focus.start() }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Image(systemName: focus.running ? "pause.fill" : "play.fill")
                                .font(.largeTitle)
                                .frame(width: 92, height: 92)
                                .background(Color.loz, in: Circle())
                                .foregroundStyle(.white)
                                .shadow(color: Color.loz.opacity(0.5), radius: 12)
                        }
                        .accessibilityLabel(focus.running ? "Duraklat" : "Başlat")

                        Menu {
                            ForEach([15, 25, 45, 60, 90], id: \.self) { m in
                                Button("\(m) dk odak") { focus.setLengths(focus: m, rest: m >= 45 ? 10 : 5) }
                            }
                        } label: {
                            Image(systemName: "timer").font(.title2).frame(width: 60, height: 60)
                        }
                        .buttonStyle(.bordered)
                        .clipShape(Circle())
                        .disabled(focus.running)
                        .accessibilityLabel("Süre seç")
                    }

                    HStack {
                        stat("Bugün", "\(focus.today) dk")
                        stat("Bu hafta", "\(focus.week) dk")
                        stat("Toplam blok", "\(focus.sessions)")
                    }
                    Text("Telefonu kilitleyebilirsin, süre bitince bildirim gelir. Her 4 blokta bir uzun ödül sesi çalar.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .onChange(of: tl.date) { _, now in focus.check(now) }
        }
        .onChange(of: focus.finished) { _, _ in confetti += 1 }
        .overlay { ConfettiView(trigger: confetti).allowsHitTesting(false) }
        .navigationTitle("Odak")
    }

    private func timeText(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
