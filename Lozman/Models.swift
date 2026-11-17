import SwiftUI

extension Color {
    static let loz = Color(red: 0.949, green: 0.416, blue: 0.106)
}

enum PlanCategory: String, Codable, CaseIterable, Identifiable {
    case work = "is", homework = "odev", event = "etk", personal = "kis", routine = "rut"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work: return "İş"
        case .homework: return "Ödev"
        case .event: return "Etkinlik"
        case .personal: return "Kişisel"
        case .routine: return "Rutin"
        }
    }

    var color: Color {
        switch self {
        case .work: return .blue
        case .homework: return .purple
        case .event: return .pink
        case .personal: return .teal
        case .routine: return .gray
        }
    }

    var symbol: String {
        switch self {
        case .work: return "briefcase.fill"
        case .homework: return "book.fill"
        case .event: return "ticket.fill"
        case .personal: return "person.fill"
        case .routine: return "arrow.triangle.2.circlepath"
        }
    }
}

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none = "yok", daily = "gun", weekdays = "hici", weekly = "hafta", monthly = "ay", yearly = "yil"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Tekrar yok"
        case .daily: return "Her gün"
        case .weekdays: return "Hafta içi her gün"
        case .weekly: return "Her hafta"
        case .monthly: return "Her ay"
        case .yearly: return "Her yıl"
        }
    }
}

enum ReminderOffset: String, CaseIterable, Identifiable {
    case atTime = "0", min15 = "15m", hour1 = "1h", morning = "morn", eveningBefore = "eve", day1 = "1d", day2 = "2d", week1 = "1w"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .atTime: return "Tam zamanında"
        case .min15: return "15 dakika önce"
        case .hour1: return "1 saat önce"
        case .morning: return "O sabah 08:00"
        case .eveningBefore: return "Önceki akşam 21:00"
        case .day1: return "1 gün önce"
        case .day2: return "2 gün önce"
        case .week1: return "1 hafta önce"
        }
    }
}

struct Plan: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var category: PlanCategory = .personal
    var date: String
    var time: String = ""
    var repeatRule: RepeatRule = .none
    var reminders: [String] = ["0"]
    var askAfter: Int = 0
    var note: String = ""
    var done: [String: Bool] = [:]
    var fromMatch: String? = nil
    var star: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, title, category = "cat", date, time, repeatRule = "repeat", reminders = "rem"
        case askAfter = "ask", note, done, fromMatch = "bjk", star
    }
}

extension Plan {
    func occurs(on day: String) -> Bool {
        guard day >= date else { return false }
        let cal = Calendar.current
        let a = Day.date(date)
        let b = Day.date(day)
        switch repeatRule {
        case .none:
            return day == date
        case .daily:
            return true
        case .weekdays:
            let w = cal.component(.weekday, from: b)
            return w != 1 && w != 7
        case .weekly:
            return cal.component(.weekday, from: a) == cal.component(.weekday, from: b)
        case .monthly:
            return cal.component(.day, from: a) == cal.component(.day, from: b)
        case .yearly:
            return cal.component(.day, from: a) == cal.component(.day, from: b)
                && cal.component(.month, from: a) == cal.component(.month, from: b)
        }
    }

    func isDone(_ day: String) -> Bool { done[day] == true }

    var hourMinute: (Int, Int)? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }

    func dueDate(on day: String) -> Date {
        let hm = hourMinute ?? (9, 0)
        return Calendar.current.date(bySettingHour: hm.0, minute: hm.1, second: 0, of: Day.date(day)) ?? Day.date(day)
    }

    var sortTime: String { time.isEmpty ? "99" : time }
}

enum Day {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let weekdays = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"]
    static let shortWeekdays = ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"]
    static let months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
    static let shortMonths = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]

    static func key(_ d: Date) -> String { formatter.string(from: d) }
    static func date(_ k: String) -> Date { formatter.date(from: k) ?? Calendar.current.startOfDay(for: Date()) }
    static var today: String { key(Date()) }

    static func add(_ k: String, _ n: Int) -> String {
        key(Calendar.current.date(byAdding: .day, value: n, to: date(k)) ?? date(k))
    }

    static func diff(_ k: String) -> Int {
        Calendar.current.dateComponents([.day], from: date(today), to: date(k)).day ?? 0
    }

    static func parts(_ k: String) -> (day: Int, month: Int, weekday: Int) {
        let d = date(k)
        let cal = Calendar.current
        return (cal.component(.day, from: d), cal.component(.month, from: d) - 1, cal.component(.weekday, from: d) - 1)
    }

    static func long(_ k: String) -> String {
        let p = parts(k)
        return "\(p.day) \(months[p.month]) \(weekdays[p.weekday])"
    }

    static func nice(_ k: String) -> String {
        switch diff(k) {
        case 0: return "Bugün"
        case 1: return "Yarın"
        case -1: return "Dün"
        default: return long(k)
        }
    }

    static func inDays(_ k: String) -> String {
        let n = diff(k)
        if n == 0 { return "Bugün" }
        if n == 1 { return "Yarın" }
        return "\(n) gün sonra"
    }
}

struct EditRequest: Identifiable {
    let id = UUID()
    let plan: Plan?
    let day: String
}

struct AskItem: Identifiable {
    let plan: Plan
    let day: String
    var id: String { plan.id + day }
}
