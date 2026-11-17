import Foundation
import UIKit
import UserNotifications

enum Notifier {
    static let center = UNUserNotificationCenter.current()
    static let planCategory = "PLAN"

    static func setup() {
        let done = UNNotificationAction(identifier: "DONE", title: "Yaptım", options: [])
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "1 saat ertele", options: [])
        let category = UNNotificationCategory(identifier: planCategory, actions: [done, snooze], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    static func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async { reschedule(PlanStore.shared.plans) }
            }
        }
    }

    static func fireDate(for code: String, plan: Plan, day: String) -> Date? {
        let cal = Calendar.current
        let due = plan.dueDate(on: day)
        let start = Day.date(day)
        switch code {
        case "0": return due
        case "15m": return due.addingTimeInterval(-15 * 60)
        case "1h": return due.addingTimeInterval(-60 * 60)
        case "morn": return cal.date(bySettingHour: 8, minute: 0, second: 0, of: start)
        case "eve":
            guard let nine = cal.date(bySettingHour: 21, minute: 0, second: 0, of: start) else { return nil }
            return cal.date(byAdding: .day, value: -1, to: nine)
        case "1d": return cal.date(byAdding: .day, value: -1, to: due)
        case "2d": return cal.date(byAdding: .day, value: -2, to: due)
        case "1w": return cal.date(byAdding: .day, value: -7, to: due)
        default: return nil
        }
    }

    static func whenText(for code: String, plan: Plan, day: String) -> String {
        let t = plan.time.isEmpty ? "" : " \(plan.time)"
        let p = Day.parts(day)
        let dayName = "\(p.day) \(Day.months[p.month]) \(Day.weekdays[p.weekday])"
        switch code {
        case "0": return plan.time.isEmpty ? "Bugün" : "Şimdi, \(plan.time)"
        case "15m": return "15 dakika sonra\(t)"
        case "1h": return "1 saat sonra\(t)"
        case "morn": return "Bugün\(t)"
        case "eve", "1d": return "Yarın\(t)"
        case "2d": return "2 gün sonra, \(dayName)\(t)"
        case "1w": return "1 hafta sonra, \(dayName)\(t)"
        default: return dayName
        }
    }

    static let sounds: [(id: String, name: String)] = [
        ("lz_zil", "Zil"), ("lz_marimba", "Marimba"), ("lz_dikkat", "Dikkat (bip bip)"), ("default", "iPhone varsayılanı")
    ]

    static var currentSound: UNNotificationSound {
        let id = UserDefaults.standard.string(forKey: "notifSound") ?? "lz_zil"
        if id == "default" { return .default }
        return UNNotificationSound(named: UNNotificationSoundName("\(id).wav"))
    }

    /// Working hours, in minutes after midnight.
    static var work: (on: Bool, start: Int, end: Int) {
        let d = UserDefaults.standard
        return (d.object(forKey: "workOn") as? Bool ?? true,
                d.object(forKey: "workStart") as? Int ?? 9 * 60,
                d.object(forKey: "workEnd") as? Int ?? 18 * 60)
    }

    static func isWorkday(_ day: String) -> Bool {
        let w = Calendar.current.component(.weekday, from: Day.date(day))
        return w != 1 && w != 7
    }

    private static func content(title: String, body: String, plan: Plan?, day: String, route: String? = nil) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = currentSound
        if let route { c.userInfo = ["route": route] }
        if let plan {
            c.categoryIdentifier = planCategory
            c.userInfo = ["plan": plan.id, "day": day]
            c.threadIdentifier = plan.id
        }
        return c
    }

    static func reschedule(_ plans: [Plan]) {
        let now = Date()
        let horizon = now.addingTimeInterval(21 * 86400)
        let today = Day.today
        let defaults = UserDefaults.standard
        let nag = defaults.object(forKey: "nagOn") as? Bool ?? true
        var list: [(date: Date, id: String, content: UNMutableNotificationContent)] = []

        for offset in 0..<29 {
            let day = Day.add(today, offset)
            for p in plans where p.occurs(on: day) && p.done[day] == nil {
                for code in p.reminders {
                    guard let fire = fireDate(for: code, plan: p, day: day), fire > now, fire < horizon else { continue }
                    let body = "\(whenText(for: code, plan: p, day: day)) · \(p.category.title)"
                    list.append((fire, "\(p.id)|\(day)|\(code)", content(title: p.title, body: body, plan: p, day: day)))
                }
                if p.askAfter > 0 {
                    let fire = p.dueDate(on: day).addingTimeInterval(Double(p.askAfter) * 60)
                    if fire > now && fire < horizon {
                        list.append((fire, "\(p.id)|\(day)|ask", content(title: "Bunu yaptın mı?", body: p.title, plan: p, day: day)))
                    }
                }
                // Extra nudge if the plan is still not ticked off a while later.
                if nag, offset <= 3, !p.time.isEmpty {
                    let wait = max(120, p.askAfter + 90)
                    let fire = p.dueDate(on: day).addingTimeInterval(Double(wait) * 60)
                    let late = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Day.date(day)) ?? fire
                    if fire > now && fire < horizon && fire < late {
                        list.append((fire, "\(p.id)|\(day)|nag",
                                     content(title: "Hâlâ işaretlemedin", body: "\(p.title) · yaptın mı? Yaptıysan işaretle.", plan: p, day: day)))
                    }
                }
            }
        }

        let work = Self.work
        let morning = defaults.object(forKey: "morningSummary") as? Bool ?? true
        let evening = defaults.object(forKey: "eveningSummary") as? Bool ?? true
        let cal = Calendar.current
        let savedName = (defaults.string(forKey: "profileName") ?? "Berat").trimmingCharacters(in: .whitespacesAndNewlines)
        let morningTitle = savedName.isEmpty ? "Günaydın" : "Günaydın \(savedName)"
        for offset in 0..<14 {
            let day = Day.add(today, offset)
            if morning, let fire = cal.date(bySettingHour: 7, minute: 30, second: 0, of: Day.date(day)), fire > now {
                let items = plans.filter { $0.occurs(on: day) }.sorted { $0.sortTime < $1.sortTime }
                let body = items.isEmpty ? "Bugün için plan yok. Rahat bir gün." :
                    "Bugün \(items.count) planın var: " + items.prefix(3).map { $0.time.isEmpty ? $0.title : "\($0.time) \($0.title)" }.joined(separator: ", ")
                list.append((fire, "summary|\(day)|morning", content(title: morningTitle, body: body + "\nDokun, günün 3 önceliğini seç.", plan: nil, day: day, route: "morning")))
            }
            let dayPlans = plans.filter { $0.occurs(on: day) }

            // End of the working day: what is left at work, what is planned for the evening.
            if work.on, isWorkday(day),
               let fire = cal.date(bySettingHour: work.end / 60, minute: work.end % 60, second: 0, of: Day.date(day)), fire > now {
                let openWork = dayPlans.filter { $0.category == .work && !$0.isDone(day) }
                let evening = dayPlans.filter { $0.category != .work && !$0.isDone(day) && $0.sortTime >= String(format: "%02d:%02d", work.end / 60, work.end % 60) }
                    .sorted { $0.sortTime < $1.sortTime }
                var parts: [String] = []
                if !openWork.isEmpty { parts.append("İşaretlenmemiş \(openWork.count) iş planın var: " + openWork.prefix(2).map(\.title).joined(separator: ", ")) }
                if !evening.isEmpty { parts.append("Akşam: " + evening.prefix(3).map { "\($0.time) \($0.title)" }.joined(separator: ", ")) }
                let body = parts.isEmpty ? "İyi akşamlar, bugün iş tarafında açık plan yok." : parts.joined(separator: "\n")
                list.append((fire, "summary|\(day)|workend", content(title: "Mesai bitti", body: body, plan: nil, day: day)))
            }

            // Evening: close the day.
            if nag, offset <= 3, let fire = cal.date(bySettingHour: 21, minute: 30, second: 0, of: Day.date(day)), fire > now {
                let open = dayPlans.filter { $0.done[day] == nil }
                if !open.isEmpty {
                    var body = open.prefix(3).map { $0.time.isEmpty ? $0.title : "\($0.time) \($0.title)" }.joined(separator: "\n")
                    if open.count > 3 { body += "\nve \(open.count - 3) plan daha" }
                    body += "\nDokun: yaptıklarını işaretle, kalanları yarına taşı."
                    list.append((fire, "summary|\(day)|open", content(title: "Günü kapatalım · \(open.count) iş açık", body: body, plan: nil, day: day, route: "review")))
                }
            }

            let tomorrow = Day.add(day, 1)
            let items = plans.filter { $0.occurs(on: tomorrow) }.sorted { $0.sortTime < $1.sortTime }
            if evening, !items.isEmpty, let fire = cal.date(bySettingHour: 21, minute: 0, second: 0, of: Day.date(day)), fire > now {
                var body = items.prefix(4).map { $0.time.isEmpty ? $0.title : "\($0.time) \($0.title)" }.joined(separator: "\n")
                if items.count > 4 { body += "\nve \(items.count - 4) plan daha" }
                list.append((fire, "summary|\(day)|evening", content(title: "Yarın yapacakların", body: body, plan: nil, day: day)))
            }
        }

        // Habit reminders on due days that are still open.
        for h in HabitStore.shared.habits {
            guard let m = h.reminder else { continue }
            for offset in 0..<7 {
                let day = Day.add(today, offset)
                guard h.isDue(day), !h.isDone(day),
                      let fire = cal.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Day.date(day)), fire > now else { continue }
                let streak = h.streak
                let body = streak > 0 ? "Serin \(streak) gün, bozma! 🔥" : "Bugün de yap, seriyi başlat."
                list.append((fire, "habit|\(h.id.uuidString)|\(day)", content(title: "\(h.icon) \(h.name)", body: body, plan: nil, day: day)))
            }
        }

        list.sort { $0.date < $1.date }
        let chosen = Array(list.prefix(60))

        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { !$0.hasPrefix("snooze") && !$0.hasPrefix("focus") }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for item in chosen {
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: item.id, content: item.content, trigger: trigger))
            }
        }
    }

    static func snooze(_ original: UNNotificationContent) {
        guard let c = original.mutableCopy() as? UNMutableNotificationContent else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        center.add(UNNotificationRequest(identifier: "snooze|\(Date().timeIntervalSince1970)", content: c, trigger: trigger))
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Notifier.setup()
        Background.register()
        Background.schedule()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let planId = info["plan"] as? String
        let day = info["day"] as? String
        let action = response.actionIdentifier
        let content = response.notification.request.content
        let route = info["route"] as? String
        DispatchQueue.main.async {
            if action == UNNotificationDefaultActionIdentifier, let route, let sheet = RoutineSheet(rawValue: route) {
                AppRouter.shared.sheet = sheet
            }
            if action == "DONE", let planId, let day {
                PlanStore.shared.setDone(planId, day: day, true)
            } else if action == "SNOOZE" {
                Notifier.snooze(content)
            }
            completionHandler()
        }
    }
}
