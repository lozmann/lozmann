import SwiftUI

struct PlanRow: View {
    @Environment(PlanStore.self) private var store
    let plan: Plan
    let day: String
    var showDate = false
    let onTap: () -> Void

    private var done: Bool { plan.isDone(day) }

    private var isLate: Bool {
        guard !done, !plan.time.isEmpty, day <= Day.today else { return false }
        return plan.dueDate(on: day) < Date()
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { store.toggle(plan.id, day: day) }
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(done ? Color.loz : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Tamamlanmadı yap" : "Tamamlandı yap")

            Button(action: onTap) {
                HStack(spacing: 10) {
                    Text(plan.time.isEmpty ? "–" : plan.time)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(isLate ? Color.red : (done ? Color.secondary : Color.primary))
                        .frame(width: 46, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(plan.title)
                            .strikethrough(done)
                            .foregroundStyle(done ? Color.secondary : Color.primary)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            if showDate { Text(Day.nice(day)) }
                            Circle().fill(plan.category.color).frame(width: 7, height: 7)
                            Text(plan.category.title)
                            if plan.repeatRule != .none { Text("· \(plan.repeatRule.title)") }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

struct PlanEditor: View {
    @Environment(PlanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var plan: Plan
    @State private var hasTime: Bool
    @State private var date: Date
    @State private var time: Date
    @State private var confirmDelete = false
    private let isNew: Bool

    init(plan: Plan?, day: String) {
        let p = plan ?? Plan(title: "", date: day, time: "09:00")
        _plan = State(initialValue: p)
        isNew = plan == nil
        _hasTime = State(initialValue: !p.time.isEmpty)
        _date = State(initialValue: Day.date(p.date))
        let hm = p.hourMinute ?? (9, 0)
        _time = State(initialValue: Calendar.current.date(bySettingHour: hm.0, minute: hm.1, second: 0, of: Date()) ?? Date())
    }

    private var trimmedTitle: String { plan.title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ne yapacaksın?", text: $plan.title)
                    Picker("Tür", selection: $plan.category) {
                        ForEach(PlanCategory.allCases) { c in
                            Label(c.title, systemImage: c.symbol).tag(c)
                        }
                    }
                }
                Section("Zaman") {
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    Toggle("Saat belirt", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Saat", selection: $time, displayedComponents: .hourAndMinute)
                    }
                    Picker("Tekrar", selection: $plan.repeatRule) {
                        ForEach(RepeatRule.allCases) { r in Text(r.title).tag(r) }
                    }
                }
                Section {
                    ForEach(ReminderOffset.allCases) { r in
                        Toggle(r.title, isOn: Binding(
                            get: { plan.reminders.contains(r.rawValue) },
                            set: { on in
                                if on {
                                    if !plan.reminders.contains(r.rawValue) { plan.reminders.append(r.rawValue) }
                                } else {
                                    plan.reminders.removeAll { $0 == r.rawValue }
                                }
                            }
                        ))
                    }
                } header: {
                    Text("Hatırlatmalar")
                } footer: {
                    Text("Birden fazla seçebilirsin.")
                }
                Section {
                    Picker("Sonra sor: \"Yaptın mı?\"", selection: $plan.askAfter) {
                        Text("Sorma").tag(0)
                        Text("30 dk sonra").tag(30)
                        Text("1 saat sonra").tag(60)
                        Text("2 saat sonra").tag(120)
                        Text("3 saat sonra").tag(180)
                    }
                }
                Section("Not") {
                    TextField("İsteğe bağlı", text: $plan.note, axis: .vertical)
                        .lineLimit(2...5)
                }
                if !isNew {
                    Section {
                        Button("Planı sil", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(isNew ? "Yeni plan" : "Planı düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .confirmationDialog("Bu plan silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Sil", role: .destructive) {
                    store.delete(plan.id)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        plan.title = trimmedTitle
        plan.note = plan.note.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.date = Day.key(date)
        if hasTime {
            let c = Calendar.current.dateComponents([.hour, .minute], from: time)
            plan.time = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        } else {
            plan.time = ""
        }
        store.upsert(plan)
        dismiss()
    }
}

struct TodayView: View {
    @Environment(PlanStore.self) private var store
    @Environment(BJKStore.self) private var bjk
    @Environment(ProfileStore.self) private var profile
    @Environment(HabitStore.self) private var habits
    @State private var habitConfetti = 0
    @State private var editing: EditRequest?
    @State private var quick = ""

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let base = h < 5 ? "İyi geceler" : (h < 12 ? "Günaydın" : (h < 18 ? "İyi günler" : "İyi akşamlar"))
        return profile.displayName.isEmpty ? base : "\(base) \(profile.displayName)"
    }

    var body: some View {
        let today = Day.today
        let tomorrow = Day.add(today, 1)
        let todays = store.plans(on: today)
        let doneCount = todays.filter { $0.isDone(today) }.count
        let asks = store.pendingAsks()
        let upcoming: [AskItem] = (2...7).flatMap { k -> [AskItem] in
            let d = Day.add(today, k)
            return store.plans(on: d).filter { $0.repeatRule == .none }.map { AskItem(plan: $0, day: d) }
        }

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            Text(greeting)
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ProfilePhotoPicker {
                                AvatarView(size: 48)
                            }
                            .buttonStyle(.plain)
                        }
                        Text(todays.isEmpty ? "Bugün için planın yok." :
                                (doneCount == todays.count ? "Bugünkü \(todays.count) planın da tamam." :
                                    "Bugün \(todays.count) planın var, \(doneCount) tanesi tamam."))
                            .foregroundStyle(.secondary)
                        if !todays.isEmpty {
                            ProgressView(value: Double(doneCount), total: Double(todays.count))
                                .tint(.loz)
                        }
                        TimelineView(.everyMinute) { context in
                            if let st = WorkClock.status(now: context.date) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label(st.text, systemImage: "briefcase.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if let p = st.progress {
                                        ProgressView(value: p).tint(.blue)
                                    }
                                }
                            }
                        }
                        HStack {
                            TextField("Örn. yarın 15:00 dişçi", text: $quick)
                                .submitLabel(.done)
                                .onSubmit(addQuick)
                                .padding(10)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                            Button("Ekle", action: addQuick)
                                .buttonStyle(.borderedProminent)
                                .disabled(quick.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        if !quick.trimmingCharacters(in: .whitespaces).isEmpty {
                            let p = QuickParser.parse(quick, defaultCategory: WorkClock.isWorkingNow ? .work : .personal)
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles").foregroundStyle(Color.loz)
                                Text(p.title).fontWeight(.medium).lineLimit(1)
                                Text("· " + (p.understood.isEmpty ? "Bugün" : p.understood.joined(separator: " · ")))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Text(p.category.title)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(p.category.color.opacity(0.18), in: Capsule())
                            }
                            .font(.caption)
                            .transition(.opacity)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if !habits.dueToday.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(habits.dueToday) { h in
                                    HabitChip(habit: h) {
                                        withAnimation(.snappy) {
                                            let s = habits.toggle(h.id)
                                            celebrateHabit(streak: s, confetti: &habitConfetti)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        let done = habits.dueToday.filter { $0.isDone(Day.today) }.count
                        HStack {
                            Text("Alışkanlıklar")
                            Spacer()
                            Text("\(done)/\(habits.dueToday.count)")
                        }
                    }
                }

                if !asks.isEmpty {
                    Section("Bunu yaptın mı?") {
                        ForEach(asks) { a in
                            PlanRow(plan: a.plan, day: a.day, showDate: a.day != today) {
                                editing = EditRequest(plan: a.plan, day: a.day)
                            }
                            .listRowBackground(Color.loz.opacity(0.12))
                        }
                    }
                }

                Section {
                    if todays.isEmpty {
                        Text("Bugün boş. Yukarıdan bir plan ekleyebilirsin.").foregroundStyle(.secondary)
                    } else {
                        ForEach(todays) { p in
                            PlanRow(plan: p, day: today) { editing = EditRequest(plan: p, day: today) }
                                .swipeActions {
                                    Button(role: .destructive) { store.delete(p.id) } label: { Label("Sil", systemImage: "trash") }
                                }
                        }
                    }
                } header: {
                    HStack {
                        Text("Bugün")
                        Spacer()
                        if !todays.isEmpty { Text("\(doneCount)/\(todays.count)") }
                    }
                }

                Section("Yarın yapacakların") {
                    let list = store.plans(on: tomorrow)
                    if list.isEmpty {
                        Text("Yarın için plan yok.").foregroundStyle(.secondary)
                    } else {
                        ForEach(list) { p in
                            PlanRow(plan: p, day: tomorrow) { editing = EditRequest(plan: p, day: tomorrow) }
                        }
                    }
                }

                if let m = bjk.nextMatch {
                    Section("Beşiktaş") {
                        MatchCard(match: m)
                    }
                }

                if !upcoming.isEmpty {
                    Section("Bu hafta yaklaşanlar") {
                        ForEach(upcoming) { a in
                            PlanRow(plan: a.plan, day: a.day, showDate: true) { editing = EditRequest(plan: a.plan, day: a.day) }
                        }
                    }
                }
            }
            .navigationTitle(Day.long(today))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = EditRequest(plan: nil, day: today)
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .accessibilityLabel("Yeni plan")
                }
            }
            .sheet(item: $editing) { r in PlanEditor(plan: r.plan, day: r.day) }
            .overlay { ConfettiView(trigger: habitConfetti).allowsHitTesting(false) }
        }
    }

    private func addQuick() {
        let text = quick.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let p = QuickParser.parse(text, defaultCategory: WorkClock.isWorkingNow ? .work : .personal)
        var time = p.time
        if time.isEmpty && p.date == Day.today {
            let next = Calendar.current.component(.hour, from: Date()) + 1
            time = next <= 23 ? String(format: "%02d:00", next) : "23:59"
        }
        var reminders = ["0"]
        if Day.diff(p.date) >= 2 { reminders.append("1d") }
        store.upsert(Plan(title: p.title, category: p.category, date: p.date, time: time, repeatRule: p.repeatRule, reminders: reminders))
        Sfx.play("pop")
        quick = ""
    }
}

struct CalendarScreen: View {
    @Environment(PlanStore.self) private var store
    @State private var selected = Date()
    @State private var editing: EditRequest?

    var body: some View {
        let day = Day.key(selected)
        let list = store.plans(on: day)
        NavigationStack {
            List {
                Section {
                    DatePicker("Gün", selection: $selected, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                Section(Day.nice(day)) {
                    if list.isEmpty {
                        Text("Bu gün için plan yok.").foregroundStyle(.secondary)
                    } else {
                        ForEach(list) { p in
                            PlanRow(plan: p, day: day) { editing = EditRequest(plan: p, day: day) }
                        }
                    }
                    Button {
                        editing = EditRequest(plan: nil, day: day)
                    } label: {
                        Label("Bu güne plan ekle", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Takvim")
            .sheet(item: $editing) { r in PlanEditor(plan: r.plan, day: r.day) }
        }
    }
}

struct PlansView: View {
    @Environment(PlanStore.self) private var store
    @State private var search = ""
    @State private var filter: PlanCategory?
    @State private var editing: EditRequest?

    var body: some View {
        let today = Day.today
        let q = search.trimmingCharacters(in: .whitespaces).lowercased(with: Locale(identifier: "tr_TR"))
        let all = store.plans.filter { p in
            (filter == nil || p.category == filter) &&
            (q.isEmpty || p.title.lowercased(with: Locale(identifier: "tr_TR")).contains(q))
        }
        let byDate: (Plan, Plan) -> Bool = { ($0.date + $0.sortTime) < ($1.date + $1.sortTime) }
        let repeating = all.filter { $0.repeatRule != .none }.sorted(by: byDate)
        let future = all.filter { $0.repeatRule == .none && $0.date >= today }.sorted(by: byDate)
        let past = all.filter { $0.repeatRule == .none && $0.date < today }.sorted(by: byDate).reversed()

        Group {
            List {
                if all.isEmpty {
                    Text(store.plans.isEmpty ? "Henüz plan yok." : "Aramana uyan plan yok.")
                        .foregroundStyle(.secondary)
                }
                planSection("Yaklaşan", future)
                planSection("Tekrarlayan", repeating)
                planSection("Geçmiş", Array(past))
            }
            .navigationTitle("Planlar")
            .searchable(text: $search, prompt: "Planlarda ara")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Hepsi") { filter = nil }
                        ForEach(PlanCategory.allCases) { c in
                            Button { filter = c } label: { Label(c.title, systemImage: c.symbol) }
                        }
                    } label: {
                        Label(filter?.title ?? "Hepsi", systemImage: "line.3.horizontal.decrease.circle")
                            .labelStyle(.titleAndIcon)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = EditRequest(plan: nil, day: today)
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .accessibilityLabel("Yeni plan")
                }
            }
            .sheet(item: $editing) { r in PlanEditor(plan: r.plan, day: r.day) }
        }
    }

    @ViewBuilder
    private func planSection(_ title: String, _ items: [Plan]) -> some View {
        if !items.isEmpty {
            Section("\(title) · \(items.count)") {
                ForEach(items) { p in
                    Button {
                        editing = EditRequest(plan: p, day: p.date)
                    } label: {
                        HStack(spacing: 10) {
                            Text(p.time.isEmpty ? "–" : p.time)
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .frame(width: 46, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.title)
                                HStack(spacing: 6) {
                                    Text(Day.nice(p.date))
                                    Circle().fill(p.category.color).frame(width: 7, height: 7)
                                    Text(p.category.title)
                                    if p.repeatRule != .none { Text("· \(p.repeatRule.title)") }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) { store.delete(p.id) } label: { Label("Sil", systemImage: "trash") }
                    }
                }
            }
        }
    }
}
