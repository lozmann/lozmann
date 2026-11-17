import SwiftUI
import UIKit
import UserNotifications

struct MatchCard: View {
    @Environment(PlanStore.self) private var store
    let match: Fixture

    var body: some View {
        let p = Day.parts(match.date)
        let planned = store.hasMatchPlan(match.date)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SIRADAKİ MAÇ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.loz)
                Spacer()
                Text(match.week.map { "\(match.comp) · \($0). hafta" } ?? match.comp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(match.home)
                    .foregroundStyle(match.isHome ? Color.loz : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("–").foregroundStyle(.secondary)
                Text(match.away)
                    .foregroundStyle(match.isHome ? Color.primary : Color.loz)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            HStack {
                Text("\(p.day) \(Day.months[p.month]) \(Day.weekdays[p.weekday]) · \(match.time.isEmpty ? "saat belli değil" : match.time)")
                Spacer()
                Text(Day.inDays(match.date)).fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Button {
                store.addMatch(match)
            } label: {
                Text(planned ? "Planına eklendi" : "Planıma ekle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(planned)
        }
        .padding(.vertical, 6)
    }
}

struct BJKView: View {
    @Environment(BJKStore.self) private var bjk
    @Environment(PlanStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                if let error = bjk.errorText {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }
                if let data = bjk.data {
                    let fixtures = bjk.upcoming
                    if let first = fixtures.first {
                        Section { MatchCard(match: first) }
                    }
                    if fixtures.count > 1 {
                        Section("Gelecek maçlar") {
                            ForEach(fixtures.dropFirst()) { f in fixtureRow(f) }
                        }
                    }
                    if fixtures.isEmpty {
                        Text("Listede gelecek maç kalmadı. Veriler yakında güncellenecek.")
                            .foregroundStyle(.secondary)
                    }
                    if !data.results.isEmpty {
                        Section("Son lig maçları") {
                            ForEach(data.results.sorted { $0.date > $1.date }) { r in
                                HStack {
                                    Circle()
                                        .fill(r.outcome == "G" ? Color.green : (r.outcome == "M" ? Color.red : Color.gray))
                                        .frame(width: 8, height: 8)
                                    Text("\(r.home) \(r.hs)–\(r.awayScore) \(r.away)")
                                    Spacer()
                                    Text(Day.nice(r.date)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Section {
                        tableHeader
                        ForEach(data.table) { row in
                            tableRow(row)
                                .listRowBackground(row.t == "Beşiktaş" ? Color.loz.opacity(0.14) : nil)
                        }
                    } header: {
                        Text("Süper Lig puan durumu")
                    } footer: {
                        Text("Son güncelleme: \(Day.long(data.updated)). Kaynak: \(data.source). Veriler her sabah güncellenir, aşağı çekerek yenileyebilirsin.")
                    }
                } else if bjk.loading {
                    ProgressView()
                } else {
                    Text("Maç bilgilerine ulaşılamadı. İnternet bağlantını kontrol edip aşağı çekerek yenile.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Beşiktaş")
            .refreshable { await bjk.refresh() }
        }
    }

    private func fixtureRow(_ f: Fixture) -> some View {
        let p = Day.parts(f.date)
        let planned = store.hasMatchPlan(f.date)
        return HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text("\(p.day)").font(.title3.weight(.bold).monospacedDigit())
                Text("\(Day.shortMonths[p.month]) \(Day.shortWeekdays[p.weekday])")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(f.home) – \(f.away)")
                Text("\(f.time.isEmpty ? "Saat belli değil" : f.time) · \(f.comp) · \(f.isHome ? "İç saha" : "Deplasman")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(planned ? "Planda" : "Plana ekle") { store.addMatch(f) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(planned)
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 24, alignment: .leading)
            Text("Takım").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(["O", "G", "B", "M", "Av", "P"], id: \.self) { h in
                Text(h).frame(width: h == "Av" ? 34 : 26, alignment: .trailing)
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func tableRow(_ r: TableRow) -> some View {
        let me = r.t == "Beşiktaş"
        return HStack(spacing: 0) {
            Text("\(r.r)").foregroundStyle(.secondary).frame(width: 24, alignment: .leading)
            Text(r.t).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity, alignment: .leading)
            Text("\(r.o)").frame(width: 26, alignment: .trailing)
            Text("\(r.g)").frame(width: 26, alignment: .trailing)
            Text("\(r.b)").frame(width: 26, alignment: .trailing)
            Text("\(r.m)").frame(width: 26, alignment: .trailing)
            Text(r.av > 0 ? "+\(r.av)" : "\(r.av)").frame(width: 34, alignment: .trailing)
            Text("\(r.p)").fontWeight(.bold).frame(width: 26, alignment: .trailing)
        }
        .font(.subheadline.monospacedDigit())
        .fontWeight(me ? .semibold : .regular)
        .foregroundStyle(me ? Color.loz : Color.primary)
    }
}

struct SettingsView: View {
    @Environment(PlanStore.self) private var store
    @AppStorage("morningSummary") private var morning = true
    @AppStorage("eveningSummary") private var evening = true
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var pending = 0

    var body: some View {
        NavigationStack {
            Form {
                ProfileSection()

                Section {
                    HStack {
                        Text("Bildirim izni")
                        Spacer()
                        Text(status == .authorized ? "Açık" : (status == .denied ? "Kapalı" : "Sorulmadı"))
                            .foregroundStyle(status == .authorized ? Color.green : Color.red)
                    }
                    if status != .authorized {
                        Button("Bildirimlere izin ver") {
                            if status == .notDetermined {
                                Notifier.requestAuthorization()
                            } else if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    HStack {
                        Text("Kurulu bildirim")
                        Spacer()
                        Text("\(pending)").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Bildirimler")
                } footer: {
                    Text("iPhone bir uygulamaya en fazla 64 bekleyen bildirim izni veriyor. Lozman en yakın 3 haftayı kurar ve uygulamayı her açtığında listeyi tazeler.")
                }

                Section("Günlük özet") {
                    Toggle("Sabah 07:30'da günün programı", isOn: $morning)
                    Toggle("Akşam 21:00'de yarının planları", isOn: $evening)
                }

                Section {
                    Text("Lozman ücretsiz Apple ID ile yüklendiği için imzası 7 günde bir yenilenmeli. Bilgisayarın açık, AltServer çalışıyor ve telefonun aynı Wi-Fi'deyken AltStore bunu kendisi yapar. Yenilenmezse uygulama açılmaz ama planların silinmez.")
                        .font(.callout)
                } header: {
                    Text("AltStore")
                }

                Section {
                    Text("\(store.plans.count) plan kayıtlı")
                    Text("Sürüm \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ayarlar")
            .onChange(of: morning) { _, _ in refresh() }
            .onChange(of: evening) { _, _ in refresh() }
            .task { await loadStatus() }
        }
    }

    private func refresh() {
        Notifier.reschedule(store.plans)
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await loadStatus()
        }
    }

    @MainActor
    private func loadStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        status = settings.authorizationStatus
        pending = await UNUserNotificationCenter.current().pendingNotificationRequests().count
    }
}
