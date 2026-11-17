import Foundation

enum WorkClock {
    static func minutes(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func format(_ m: Int) -> String { String(format: "%02d:%02d", m / 60, m % 60) }

    static var isWorkingNow: Bool {
        let w = Notifier.work
        let m = minutes(Date())
        return w.on && Notifier.isWorkday(Day.today) && m >= w.start && m < w.end
    }

    static func status(now: Date) -> (text: String, progress: Double?)? {
        let w = Notifier.work
        guard w.on, w.end > w.start, Notifier.isWorkday(Day.key(now)) else { return nil }
        let m = minutes(now)
        if m < w.start { return ("Mesai \(format(w.start))'da başlıyor", nil) }
        if m >= w.end { return ("Mesai bitti, iyi akşamlar", nil) }
        let left = w.end - m
        let leftText = left >= 60 ? "\(left / 60) sa \(left % 60) dk" : "\(left) dk"
        return ("Mesaidesin · bitişe \(leftText)", Double(m - w.start) / Double(w.end - w.start))
    }
}
