import Foundation
import Observation

@Observable
final class PlanStore {
    static let shared = PlanStore()

    var plans: [Plan] = []

    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("plans.json")

    private init() {
        load()
    }

    private func load() {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Plan].self, from: data) {
            plans = decoded
        } else if !UserDefaults.standard.bool(forKey: "seeded") {
            plans = Seed.plans
            UserDefaults.standard.set(true, forKey: "seeded")
            save()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(plans) {
            try? data.write(to: url, options: .atomic)
        }
        Notifier.reschedule(plans)
    }

    func upsert(_ plan: Plan) {
        if let i = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[i] = plan
        } else {
            plans.append(plan)
        }
        save()
    }

    func delete(_ id: String) {
        plans.removeAll { $0.id == id }
        save()
    }

    func setDone(_ id: String, day: String, _ value: Bool) {
        guard let i = plans.firstIndex(where: { $0.id == id }) else { return }
        let limit = Day.add(Day.today, -120)
        plans[i].done = plans[i].done.filter { $0.key >= limit }
        if value {
            plans[i].done[day] = true
        } else {
            plans[i].done.removeValue(forKey: day)
        }
        save()
    }

    /// "Yapmadım": answers the question without marking the plan done.
    func markSkipped(_ id: String, day: String) {
        guard let i = plans.firstIndex(where: { $0.id == id }) else { return }
        plans[i].done[day] = false
        save()
    }

    func toggle(_ id: String, day: String) {
        guard let p = plans.first(where: { $0.id == id }) else { return }
        setDone(id, day: day, !p.isDone(day))
    }

    func plans(on day: String) -> [Plan] {
        plans.filter { $0.occurs(on: day) }.sorted { $0.sortTime < $1.sortTime }
    }

    func pendingAsks() -> [AskItem] {
        let now = Date()
        var out: [AskItem] = []
        for k in 0..<7 {
            let day = Day.add(Day.today, -k)
            for p in plans(on: day) where p.askAfter > 0 && p.done[day] == nil {
                if p.dueDate(on: day).addingTimeInterval(Double(p.askAfter) * 60) <= now {
                    out.append(AskItem(plan: p, day: day))
                }
            }
        }
        return out
    }

    func hasMatchPlan(_ date: String) -> Bool {
        plans.contains { $0.fromMatch == date }
    }

    func addMatch(_ f: Fixture) {
        guard !hasMatchPlan(f.date) else { return }
        upsert(Plan(title: "\(f.home) – \(f.away)", category: .event, date: f.date, time: f.time,
                    reminders: ["1h"], note: f.comp, fromMatch: f.date))
    }
}

enum Seed {
    static let plans: [Plan] = [
        Plan(title: "Tayland için sunum hazırla", category: .work, date: "2026-11-17", time: "10:00", reminders: ["0", "15m"], askAfter: 30),
        Plan(title: "Mesut Hoca ödevler yapılacak", category: .homework, date: "2026-11-17", time: "12:00", reminders: ["0", "15m"], askAfter: 30),
        Plan(title: "Small talks etkinlik için Sema ile konuş", category: .event, date: "2026-11-17", time: "16:00", reminders: ["0"], askAfter: 60),
        Plan(title: "Mesut Hoca ders", category: .work, date: "2026-11-17", time: "17:00", reminders: ["0", "15m"], askAfter: 60),
        Plan(title: "Advent Calendar ve balık sipariş et", category: .personal, date: "2026-11-18", time: "11:00", reminders: ["0"], askAfter: 30),
        Plan(title: "Mesut Hoca ders", category: .homework, date: "2026-11-18", time: "16:00", reminders: ["0"], askAfter: 30),
        Plan(title: "Birlik Vakfı", category: .event, date: "2026-11-18", time: "20:00", reminders: ["0"], askAfter: 30),
        Plan(title: "Birlik Vakfı", category: .event, date: "2026-11-19", time: "16:00", reminders: ["0"], askAfter: 60)
    ]
}
