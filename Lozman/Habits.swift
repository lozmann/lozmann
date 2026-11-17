import SwiftUI
import Observation
import UIKit

struct Habit: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var icon: String = "🔥"
    var weekdays: [Int] = [1, 2, 3, 4, 5, 6, 7]   // Calendar weekday numbers, 1 = Sunday
    var reminder: Int? = nil                        // minutes after midnight
    var done: [String: Bool] = [:]
    var created = Date()

    func isDue(_ day: String) -> Bool {
        weekdays.contains(Calendar.current.component(.weekday, from: Day.date(day)))
    }

    func isDone(_ day: String) -> Bool { done[day] == true }

    /// Consecutive due days completed, ending today (or yesterday if today is still open).
    var streak: Int {
        var n = 0
        var day = Day.today
        if isDue(day) && !isDone(day) { day = Day.add(day, -1) }
        var guardDays = 0
        while guardDays < 1000 {
            guardDays += 1
            if !isDue(day) { day = Day.add(day, -1); continue }
            if isDone(day) { n += 1; day = Day.add(day, -1) } else { break }
        }
        return n
    }

    var longest: Int {
        let keys = done.filter { $0.value }.keys.sorted()
        guard let first = keys.first else { return 0 }
        var best = 0, run = 0
        var day = first
        while day <= Day.today {
            if isDue(day) {
                if isDone(day) { run += 1; best = max(best, run) } else { run = 0 }
            }
            day = Day.add(day, 1)
        }
        return best
    }

    func rate(days: Int) -> Double {
        var due = 0, ok = 0
        for k in 0..<days {
            let d = Day.add(Day.today, -k)
            if d < Day.key(created) { break }
            if isDue(d) {
                due += 1
                if isDone(d) { ok += 1 }
            }
        }
        return due == 0 ? 0 : Double(ok) / Double(due)
    }
}

@Observable
final class HabitStore {
    static let shared = HabitStore()

    var habits: [Habit] = []

    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("habits.json")

    private init() {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(habits) {
            try? data.write(to: url, options: .atomic)
        }
        Notifier.reschedule(PlanStore.shared.plans)
    }

    func upsert(_ h: Habit) {
        if let i = habits.firstIndex(where: { $0.id == h.id }) { habits[i] = h } else { habits.append(h) }
        save()
    }

    func delete(_ id: UUID) {
        habits.removeAll { $0.id == id }
        save()
    }

    /// Returns the new streak if the habit was just completed.
    @discardableResult
    func toggle(_ id: UUID, day: String = Day.today) -> Int? {
        guard let i = habits.firstIndex(where: { $0.id == id }) else { return nil }
        if habits[i].isDone(day) {
            habits[i].done.removeValue(forKey: day)
            save()
            return nil
        }
        habits[i].done[day] = true
        save()
        return habits[i].streak
    }

    var dueToday: [Habit] { habits.filter { $0.isDue(Day.today) } }
}

/// Plays the right reward for finishing a habit.
func celebrateHabit(streak: Int?, confetti: inout Int) {
    guard let s = streak else { return }
    if [3, 7, 14, 21, 30, 50, 100].contains(s) || (s > 100 && s % 50 == 0) {
        Sfx.play("levelup")
        confetti += 1
    } else {
        Sfx.play("correct")
    }
    UINotificationFeedbackGenerator().notificationOccurred(.success)
}

struct HabitChip: View {
    let habit: Habit
    let action: () -> Void

    var body: some View {
        let done = habit.isDone(Day.today)
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(done ? Color.loz : Color(.secondarySystemBackground))
                        .frame(width: 54, height: 54)
                    Text(habit.icon).font(.system(size: 26))
                        .opacity(done ? 1 : 0.85)
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .green)
                            .offset(x: 20, y: 20)
                    }
                }
                Text(habit.name).font(.caption).lineLimit(1).frame(width: 70)
                Text(habit.streak > 0 ? "🔥 \(habit.streak)" : " ").font(.caption2.weight(.bold)).foregroundStyle(Color.loz)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habit.name), \(done ? "yapıldı" : "yapılmadı"), seri \(habit.streak)")
    }
}

struct HabitsView: View {
    @Environment(HabitStore.self) private var store
    @State private var editing: Habit?
    @State private var confetti = 0

    var body: some View {
        List {
            if store.habits.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Henüz alışkanlık yok").font(.headline)
                    Text("Her gün su içmek, spor, kitap okumak, İngilizce çalışmak… Her gün işaretle, serini büyüt.")
                        .foregroundStyle(.secondary)
                    Button("İlk alışkanlığını ekle") { editing = Habit(name: "") }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 6)
            }
            ForEach(store.habits) { h in
                HStack(spacing: 14) {
                    Button {
                        withAnimation(.snappy) {
                            let s = store.toggle(h.id)
                            celebrateHabit(streak: s, confetti: &confetti)
                        }
                    } label: {
                        ZStack {
                            Circle().fill(h.isDone(Day.today) ? Color.loz : Color(.secondarySystemBackground)).frame(width: 46, height: 46)
                            Text(h.icon).font(.title2)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!h.isDue(Day.today))

                    Button {
                        editing = h
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(h.name).font(.headline)
                                Spacer()
                                Text("🔥 \(h.streak)").font(.subheadline.weight(.bold)).foregroundStyle(Color.loz)
                            }
                            weekDots(h)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .swipeActions {
                    Button(role: .destructive) { store.delete(h.id) } label: { Label("Sil", systemImage: "trash") }
                }
            }
        }
        .navigationTitle("Alışkanlıklar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = Habit(name: "") } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                    .accessibilityLabel("Yeni alışkanlık")
            }
        }
        .sheet(item: $editing) { h in HabitEditor(habit: h) }
        .overlay { ConfettiView(trigger: confetti).allowsHitTesting(false) }
    }

    private func weekDots(_ h: Habit) -> some View {
        HStack(spacing: 6) {
            ForEach((0..<7).reversed(), id: \.self) { k in
                let d = Day.add(Day.today, -k)
                let p = Day.parts(d)
                VStack(spacing: 2) {
                    Circle()
                        .fill(h.isDone(d) ? Color.loz : (h.isDue(d) ? Color.gray.opacity(0.25) : Color.clear))
                        .overlay(Circle().strokeBorder(Color.gray.opacity(h.isDue(d) ? 0 : 0.25), lineWidth: 1))
                        .frame(width: 14, height: 14)
                    Text(Day.shortWeekdays[p.weekday].prefix(2)).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct HabitEditor: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var habit: Habit
    @State private var hasReminder = false
    @State private var reminderTime = Date()

    private let icons = ["🔥", "💧", "🏃", "📚", "🇬🇧", "🧘", "💪", "🥗", "😴", "🚭", "🙏", "🎸", "✍️", "🧹", "💊", "🚶"]
    private let dayOrder = [2, 3, 4, 5, 6, 7, 1]
    private let dayNames = [1: "Paz", 2: "Pzt", 3: "Sal", 4: "Çar", 5: "Per", 6: "Cum", 7: "Cmt"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Örn. Kitap oku", text: $habit.name)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(icons, id: \.self) { i in
                                Text(i).font(.title2)
                                    .padding(6)
                                    .background(habit.icon == i ? Color.loz.opacity(0.25) : .clear, in: Circle())
                                    .onTapGesture { habit.icon = i }
                            }
                        }
                    }
                }
                Section("Hangi günler?") {
                    HStack {
                        ForEach(dayOrder, id: \.self) { d in
                            let on = habit.weekdays.contains(d)
                            Text(dayNames[d] ?? "")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(on ? Color.loz : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(on ? .white : .primary)
                                .onTapGesture {
                                    if on { habit.weekdays.removeAll { $0 == d } } else { habit.weekdays.append(d) }
                                }
                        }
                    }
                }
                Section {
                    Toggle("Hatırlat", isOn: $hasReminder)
                    if hasReminder {
                        DatePicker("Saat", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("O gün işaretlemediysen seçtiğin saatte hatırlatır.")
                }
                if store.habits.contains(where: { $0.id == habit.id }) {
                    Section("İstatistik") {
                        LabeledContent("Şu anki seri", value: "\(habit.streak) gün")
                        LabeledContent("En uzun seri", value: "\(habit.longest) gün")
                        LabeledContent("Son 30 gün", value: "%\(Int(habit.rate(days: 30) * 100))")
                        heatmap
                    }
                }
            }
            .navigationTitle(habit.name.isEmpty ? "Yeni alışkanlık" : habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        habit.name = habit.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if hasReminder {
                            let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                            habit.reminder = (c.hour ?? 0) * 60 + (c.minute ?? 0)
                        } else {
                            habit.reminder = nil
                        }
                        if habit.weekdays.isEmpty { habit.weekdays = [1, 2, 3, 4, 5, 6, 7] }
                        store.upsert(habit)
                        dismiss()
                    }
                    .disabled(habit.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let m = habit.reminder {
                    hasReminder = true
                    reminderTime = Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
                } else {
                    reminderTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
                }
            }
        }
    }

    /// Last 12 weeks, one square per day.
    private var heatmap: some View {
        let start = Day.add(Day.today, -83)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 12), spacing: 3) {
            ForEach(0..<84, id: \.self) { k in
                let week = k % 12, dow = k / 12
                let d = Day.add(start, week * 7 + dow)
                RoundedRectangle(cornerRadius: 3)
                    .fill(habit.isDone(d) ? Color.loz : Color.gray.opacity(habit.isDue(d) && d <= Day.today ? 0.18 : 0.06))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(.vertical, 4)
    }
}
