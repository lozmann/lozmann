import AppIntents
import Foundation

/// "Hey Siri, Lozman'a ekle" — also usable from the Action button and the Shortcuts app
/// (including a share-sheet shortcut that passes shared text in).
struct AddPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Lozman'a ekle"
    static let description = IntentDescription("Lozman'a hızlıca plan ekler. Örnek: yarın 15:00 dişçi, her gün 21:30 duş al.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Plan", requestValueDialog: IntentDialog("Ne ekleyeyim?"))
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return .result(dialog: IntentDialog("Boş bir plan ekleyemem."))
        }
        let saved = QuickAdd.save(raw)
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: "Ekledim: \(saved)")))
    }
}

struct TodayPlansIntent: AppIntent {
    static let title: LocalizedStringResource = "Bugün neyim var"
    static let description = IntentDescription("Bugünkü planlarını okur.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let today = Day.today
        let open = PlanStore.shared.plans(on: today).filter { !$0.isDone(today) }
        let text: String
        if open.isEmpty {
            text = "Bugün için açık planın yok."
        } else {
            let list = open.prefix(5).map { $0.time.isEmpty ? $0.title : "\($0.time) \($0.title)" }.joined(separator: ", ")
            text = "Bugün \(open.count) açık planın var: \(list)."
        }
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: text)))
    }
}

struct LozmanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddPlanIntent(),
            phrases: [
                "\(.applicationName)'a ekle",
                "\(.applicationName)'a plan ekle",
                "\(.applicationName) ekle"
            ],
            shortTitle: "Plan ekle",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: TodayPlansIntent(),
            phrases: [
                "\(.applicationName) bugün neyim var",
                "\(.applicationName)'da bugün neyim var"
            ],
            shortTitle: "Bugün neyim var",
            systemImageName: "sun.max.fill"
        )
    }
}

/// Shared by the Today quick-add box and Siri.
enum QuickAdd {
    /// Saves a plan from free text and returns a short description of what was saved.
    @MainActor
    @discardableResult
    static func save(_ text: String) -> String {
        let p = QuickParser.parse(text, defaultCategory: WorkClock.isWorkingNow ? .work : .personal)
        var time = p.time
        if time.isEmpty && p.date == Day.today {
            let next = Calendar.current.component(.hour, from: Date()) + 1
            time = next <= 23 ? String(format: "%02d:00", next) : "23:59"
        }
        var reminders = ["0"]
        if Day.diff(p.date) >= 2 { reminders.append("1d") }
        PlanStore.shared.upsert(Plan(title: p.title, category: p.category, date: p.date, time: time,
                                     repeatRule: p.repeatRule, reminders: reminders))
        var parts = [Day.nice(p.date)]
        if !time.isEmpty { parts.append(time) }
        if p.repeatRule != .none { parts.append(p.repeatRule.title.lowercased(with: Locale(identifier: "tr_TR"))) }
        return "\(p.title), \(parts.joined(separator: " "))"
    }
}
