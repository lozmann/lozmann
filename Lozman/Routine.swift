import SwiftUI
import Observation
import UIKit

enum RoutineSheet: String, Identifiable {
    case morning, review
    var id: String { rawValue }
}

/// Lets a notification tap open a screen.
@Observable
final class AppRouter {
    static let shared = AppRouter()
    var sheet: RoutineSheet?
}

/// Morning: pick up to three priorities for the day.
struct MorningPlanView: View {
    @Environment(PlanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var quick = ""

    var body: some View {
        let today = Day.today
        let list = store.plans(on: today)
        let stars = list.filter { $0.star == today }.count
        NavigationStack {
            List {
                Section {
                    Text("Bugün bitirirsen gününü iyi geçirmiş sayacağın en fazla 3 işi seç.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    if list.isEmpty {
                        Text("Bugün için plan yok. Aşağıdan ekleyebilirsin.").foregroundStyle(.secondary)
                    }
                    ForEach(list) { p in
                        let on = p.star == today
                        Button {
                            if on || stars < 3 {
                                withAnimation(.snappy) { store.toggleStar(p.id, day: today) }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } else {
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            }
                        } label: {
                            HStack {
                                Image(systemName: on ? "star.fill" : "star")
                                    .foregroundStyle(on ? Color.yellow : Color.secondary)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.title)
                                    if !p.time.isEmpty { Text(p.time).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Öncelikler · \(stars)/3")
                }
                Section("Aklına gelen bir şey mi var?") {
                    HStack {
                        TextField("Örn. 14:00 rapor gönder", text: $quick)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button("Ekle", action: add)
                            .disabled(quick.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Günü planla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Başla") {
                        Sfx.play("correct")
                        dismiss()
                    }
                }
            }
        }
    }

    private func add() {
        let t = quick.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        QuickAdd.save(t)
        Sfx.play("pop")
        quick = ""
    }
}

/// Evening: close the day. Everything still open gets an answer.
struct EveningReviewView: View {
    @Environment(PlanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confetti = 0
    @State private var celebrated = false

    var body: some View {
        let today = Day.today
        let items = store.openItems()
        let todays = store.plans(on: today)
        let doneToday = todays.filter { $0.isDone(today) }.count
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().stroke(Color.loz.opacity(0.18), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: todays.isEmpty ? 1 : Double(doneToday) / Double(todays.count))
                                .stroke(Color.loz, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(doneToday)/\(todays.count)").font(.headline.monospacedDigit())
                        }
                        .frame(width: 66, height: 66)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(items.isEmpty ? "Gün tamam!" : "\(items.count) iş cevap bekliyor")
                                .font(.headline)
                            Text(items.isEmpty ? "Yarın için her şey hazır. İyi dinlen." :
                                    "Yaptıklarını işaretle, kalanları yarına taşı.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !items.isEmpty {
                    Section {
                        ForEach(items) { a in
                            ReviewRow(item: a)
                        }
                    }
                    if items.contains(where: { $0.plan.repeatRule == .none }) {
                        Section {
                            Button {
                                withAnimation(.snappy) {
                                    for a in items where a.plan.repeatRule == .none {
                                        store.moveToTomorrow(a.plan.id, from: a.day)
                                    }
                                }
                                Sfx.play("pop")
                            } label: {
                                Label("Kalanların hepsini yarına taşı", systemImage: "arrow.turn.down.right")
                            }
                        }
                    }
                }

                let tomorrow = store.plans(on: Day.add(today, 1))
                if !tomorrow.isEmpty {
                    Section("Yarın") {
                        ForEach(tomorrow) { p in
                            HStack {
                                Text(p.time.isEmpty ? "–" : p.time)
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                                    .frame(width: 46, alignment: .leading)
                                Text(p.title)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Günü kapat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Bitti") { dismiss() } }
            }
            .overlay { ConfettiView(trigger: confetti).allowsHitTesting(false) }
            .onChange(of: items.isEmpty) { _, empty in
                if empty && !celebrated {
                    celebrated = true
                    confetti += 1
                    Sfx.play("levelup")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }
}

private struct ReviewRow: View {
    @Environment(PlanStore.self) private var store
    let item: AskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.plan.title).font(.body.weight(.medium))
                Spacer()
                Text(item.day == Day.today ? (item.plan.time.isEmpty ? "Bugün" : item.plan.time) : Day.nice(item.day))
                    .font(.caption)
                    .foregroundStyle(item.day == Day.today ? Color.secondary : Color.red)
            }
            HStack(spacing: 8) {
                pill("Yaptım", "checkmark", filled: true) {
                    store.setDone(item.plan.id, day: item.day, true)
                    Sfx.play("correct")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                if item.plan.repeatRule == .none {
                    pill("Yarına", "arrow.turn.down.right", filled: false) {
                        store.moveToTomorrow(item.plan.id, from: item.day)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                pill("Yapmadım", "xmark", filled: false) {
                    store.markSkipped(item.plan.id, day: item.day)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func pill(_ title: String, _ icon: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(filled ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(filled ? Color.loz : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(filled ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
