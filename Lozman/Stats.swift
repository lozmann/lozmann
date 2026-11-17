import SwiftUI
import Charts

struct StatsView: View {
    @Environment(PlanStore.self) private var plans
    @Environment(HabitStore.self) private var habits
    @Environment(FocusStore.self) private var focus

    private struct DayRow: Identifiable {
        let id = UUID()
        let label: String
        let status: String
        let count: Int
    }

    private func counts(_ day: String) -> (done: Int, total: Int) {
        let list = plans.plans(on: day)
        return (list.filter { $0.isDone(day) }.count, list.count)
    }

    private func rate(from start: Int, days: Int) -> Double {
        var d = 0, t = 0
        for k in start..<(start + days) {
            let c = counts(Day.add(Day.today, -k))
            d += c.done
            t += c.total
        }
        return t == 0 ? 0 : Double(d) / Double(t)
    }

    private var productiveStreak: Int {
        var n = 0
        var day = Day.today
        if counts(day).done == 0 { day = Day.add(day, -1) }
        while counts(day).done > 0 && n < 400 {
            n += 1
            day = Day.add(day, -1)
        }
        return n
    }

    var body: some View {
        let rows: [DayRow] = (0..<7).reversed().flatMap { k -> [DayRow] in
            let d = Day.add(Day.today, -k)
            let c = counts(d)
            let label = Day.shortWeekdays[Day.parts(d).weekday]
            return [DayRow(label: label, status: "Yapıldı", count: c.done),
                    DayRow(label: label, status: "Kaldı", count: c.total - c.done)]
        }
        let thisWeek = rate(from: 0, days: 7)
        let lastWeek = rate(from: 7, days: 7)
        let habitToday = habits.dueToday
        let habitDone = habitToday.filter { $0.isDone(Day.today) }.count

        List {
            Section {
                HStack {
                    bigStat("%\(Int(thisWeek * 100))", "Bu hafta tamamlama")
                    bigStat("\(productiveStreak) gün", "Verimli gün serisi")
                }
                if lastWeek > 0 || thisWeek > 0 {
                    let diff = Int((thisWeek - lastWeek) * 100)
                    Label(diff >= 0 ? "Geçen haftaya göre +\(diff) puan" : "Geçen haftaya göre \(diff) puan",
                          systemImage: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(diff >= 0 ? .green : .orange)
                        .font(.subheadline)
                }
            }

            Section("Son 7 gün") {
                Chart(rows) { r in
                    BarMark(x: .value("Gün", r.label), y: .value("Plan", r.count))
                        .foregroundStyle(by: .value("Durum", r.status))
                        .cornerRadius(4)
                }
                .chartForegroundStyleScale(["Yapıldı": Color.loz, "Kaldı": Color.gray.opacity(0.3)])
                .frame(height: 180)
                .padding(.vertical, 6)
            }

            Section("Odak") {
                LabeledContent("Bugün", value: "\(focus.today) dk")
                LabeledContent("Son 7 gün", value: "\(focus.week) dk")
                LabeledContent("Toplam blok", value: "\(focus.sessions)")
            }

            Section("Alışkanlıklar") {
                if habits.habits.isEmpty {
                    Text("Henüz alışkanlık eklemedin.").foregroundStyle(.secondary)
                } else {
                    LabeledContent("Bugün", value: "\(habitDone)/\(habitToday.count)")
                    ForEach(habits.habits) { h in
                        HStack {
                            Text("\(h.icon) \(h.name)")
                            Spacer()
                            Text("🔥 \(h.streak) · %\(Int(h.rate(days: 30) * 100))")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("İstatistikler")
    }

    private func bigStat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(Color.loz)
            Text(title).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
