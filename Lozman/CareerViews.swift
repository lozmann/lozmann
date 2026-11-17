import SwiftUI
import UIKit

private let gold = Color(red: 0.96, green: 0.80, blue: 0.38)
private let lfcRed = Color(red: 0.78, green: 0.06, blue: 0.18)

// MARK: - Player card

struct PlayerCardView: View {
    let attrs: CarAttributes
    let club: String

    var body: some View {
        let age = Calendar.current.component(.year, from: Date()) - CareerHistory.birthYear
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Color(red: 0.99, green: 0.90, blue: 0.55), gold, Color(red: 0.72, green: 0.52, blue: 0.16)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                )
                .shadow(color: gold.opacity(0.5), radius: 18, y: 8)
            // soft light streak
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    VStack(spacing: 2) {
                        Text("\(attrs.overall)").font(.system(size: 46, weight: .black, design: .rounded))
                        Text(CareerHistory.position).font(.caption.weight(.heavy))
                        Text("🇹🇷").font(.title2).padding(.top, 4)
                        Text(club.uppercased()).font(.system(size: 9, weight: .heavy)).padding(.top, 2)
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(Color.white.opacity(0.25)).frame(width: 118, height: 118)
                        Image(systemName: "figure.soccer")
                            .font(.system(size: 70, weight: .regular))
                            .foregroundStyle(Color(red: 0.35, green: 0.22, blue: 0.05).opacity(0.85))
                        Text("\(CareerHistory.number)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(lfcRed, in: Circle())
                            .offset(x: 46, y: 42)
                    }
                    Spacer()
                }
                Text(CareerHistory.name.uppercased())
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .tracking(1)
                Rectangle().fill(Color.black.opacity(0.2)).frame(height: 1).padding(.horizontal, 30)
                HStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 4) {
                        attr("HIZ", attrs.pac)
                        attr("ŞUT", attrs.sho)
                        attr("PAS", attrs.pas)
                    }
                    Rectangle().fill(Color.black.opacity(0.2)).frame(width: 1, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        attr("DRİ", attrs.dri)
                        attr("DEF", attrs.def)
                        attr("FİZ", attrs.phy)
                    }
                }
                Text("\(age) yaş · \(CareerHistory.height) · \(CareerHistory.foot) ayak")
                    .font(.caption.weight(.semibold))
                    .opacity(0.75)
            }
            .foregroundStyle(Color(red: 0.25, green: 0.16, blue: 0.03))
            .padding(22)
        }
        .frame(maxWidth: 340)
        .accessibilityElement(children: .combine)
    }

    private func attr(_ name: String, _ v: Double) -> some View {
        HStack(spacing: 6) {
            Text("\(Int(v))").font(.system(size: 18, weight: .black, design: .rounded).monospacedDigit())
            Text(name).font(.system(size: 14, weight: .semibold))
        }
    }
}

// MARK: - Career hub

struct CareerView: View {
    @Environment(CareerStore.self) private var career
    @State private var playing: CarFixture?
    @State private var showTraining = false

    var body: some View {
        let s = career.state
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PlayerCardView(attrs: s.attributes, club: CarTeams.me)
                        .padding(.top, 6)

                    HStack(spacing: 10) {
                        bigNumber("\(career.totalApps)", "Maç")
                        bigNumber("\(career.totalGoals)", "Gol")
                        bigNumber("\(career.totalAssists)", "Asist")
                        bigNumber("\(career.totalTrophies)", "Kupa")
                    }

                    nextMatchCard

                    conditionCard

                    VStack(spacing: 0) {
                        link("Sezon \(s.season)", "Fikstür, puan durumu, istatistik", "calendar") { SeasonView() }
                        Divider().padding(.leading, 56)
                        link("Kariyer geçmişi", "Sezon sezon tüm rakamlar", "list.number") { HistoryView() }
                        Divider().padding(.leading, 56)
                        link("Kupa dolabı", "\(career.totalTrophies) kupa", "trophy.fill") { TrophyView() }
                        Divider().padding(.leading, 56)
                        link("Ödüller", "Ballon d'Or 2024 ve daha fazlası", "medal.fill") { AwardsView() }
                        Divider().padding(.leading, 56)
                        link("Milli takım", "\(CareerHistory.nationalCaps) maç · \(CareerHistory.nationalGoals) gol", "flag.fill") { NationalView() }
                        Divider().padding(.leading, 56)
                        link("Transfer geçmişi", "Gençlerbirliği → Beşiktaş → Liverpool", "arrow.left.arrow.right") { TransfersView() }
                    }
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                }
                .padding()
            }
            .navigationTitle("Kariyer")
            .fullScreenCover(item: $playing) { f in
                MatchView(fixture: f, attrs: s.attributes, energy: s.energy)
            }
            .sheet(isPresented: $showTraining) { TrainingView() }
        }
    }

    private func bigNumber(_ v: String, _ t: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
            Text(t).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var nextMatchCard: some View {
        if let f = career.nextFixture {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SIRADAKİ MAÇ").font(.caption.weight(.heavy)).foregroundStyle(lfcRed)
                    Spacer()
                    Text("\(f.compName) · \(f.round)").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Text(f.home ? CarTeams.me : f.opponent).font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("vs").foregroundStyle(.secondary)
                    Text(f.home ? f.opponent : CarTeams.me).font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                HStack {
                    Label(f.home ? "Anfield" : "Deplasman", systemImage: "mappin.and.ellipse")
                    Spacer()
                    Label("Rakip gücü \(CarTeams.rating(f.opponent))", systemImage: "shield.lefthalf.filled")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Button {
                    playing = f
                    Sfx.play("pop")
                } label: {
                    Label("Maça çık", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(lfcRed, in: Capsule())
                        .foregroundStyle(.white)
                }
                if career.state.energy < 30 {
                    Text("Enerjin düşük: daha az pozisyon bulursun, şutların sapar. Önce dinlenmeyi düşün.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        } else {
            VStack(spacing: 10) {
                Text("Sezon bitti!").font(.title2.weight(.heavy))
                Text(career.state.wonThisSeason.isEmpty ? "Bu sezon kupa yok. Yeni sezonda telafi edeceğiz." :
                        "Bu sezon kazandıkların: \(career.state.wonThisSeason.joined(separator: ", "))")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Yeni sezona başla") {
                    career.newSeason()
                    Sfx.play("levelup")
                }
                .buttonStyle(.borderedProminent)
                .tint(lfcRed)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var conditionCard: some View {
        let s = career.state
        return VStack(alignment: .leading, spacing: 10) {
            meter("Enerji", s.energy, .green)
            meter("Moral", s.morale, .orange)
            HStack {
                if !s.form.isEmpty {
                    Text("Form").font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(s.form.suffix(5).enumerated()), id: \.offset) { _, r in
                        Text(String(format: "%.1f", r))
                            .font(.caption.weight(.bold).monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background((r >= 8 ? Color.green : (r >= 6.5 ? Color.orange : Color.red)).opacity(0.25), in: Capsule())
                    }
                }
                Spacer()
                Text("Değer €\(career.marketValue)M").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            Button {
                showTraining = true
            } label: {
                Label("Antrenman ve dinlenme", systemImage: "figure.run")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func meter(_ title: String, _ v: Double, _ c: Color) -> some View {
        HStack {
            Text(title).font(.subheadline).frame(width: 52, alignment: .leading)
            ProgressView(value: v, total: 100).tint(c)
            Text("\(Int(v))").font(.caption.monospacedDigit()).frame(width: 30, alignment: .trailing)
        }
    }

    private func link<D: View>(_ title: String, _ subtitle: String, _ icon: String, @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(lfcRed)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Season

struct SeasonView: View {
    @Environment(CareerStore.self) private var career
    @State private var tab = 0

    var body: some View {
        List {
            Section {
                Picker("Görünüm", selection: $tab) {
                    Text("Fikstür").tag(0)
                    Text("Puan durumu").tag(1)
                    Text("İstatistik").tag(2)
                }
                .pickerStyle(.segmented)
            }
            switch tab {
            case 0: fixtures
            case 1: table
            default: stats
            }
        }
        .navigationTitle("Sezon \(career.state.season)")
    }

    @ViewBuilder
    private var fixtures: some View {
        Section {
            ForEach(career.state.fixtures) { f in
                HStack(spacing: 10) {
                    Text(f.comp == "PL" ? "PL" : "ŞL")
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background((f.comp == "PL" ? Color.purple : Color.blue).opacity(0.2), in: Capsule())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(f.home ? "vs" : "@") \(f.opponent)").font(.subheadline.weight(.medium))
                        Text(f.round).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if f.played {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(f.goalsFor)-\(f.goalsAgainst)")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(f.goalsFor > f.goalsAgainst ? Color.green : (f.goalsFor == f.goalsAgainst ? .secondary : .red))
                            Text("⚽️\(f.myGoals) 🅰️\(f.myAssists) · \(String(format: "%.1f", f.rating))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Oynanmadı").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        } footer: {
            Text("Şampiyonlar Ligi: \(career.state.uclStage) · \(career.state.uclPoints) puan (lig aşamasından çıkmak için 12 puan gerekli)")
        }
    }

    @ViewBuilder
    private var table: some View {
        Section {
            HStack {
                Text("#").frame(width: 22, alignment: .leading)
                Text("Takım")
                Spacer()
                Text("O").frame(width: 26)
                Text("Av").frame(width: 34)
                Text("P").frame(width: 30)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            ForEach(Array(career.sortedTable.enumerated()), id: \.offset) { i, row in
                HStack {
                    Text("\(i + 1)").foregroundStyle(i < 4 ? Color.blue : (i >= 17 ? Color.red : .secondary)).frame(width: 22, alignment: .leading)
                    Text(row.0).lineLimit(1)
                    Spacer()
                    Text("\(row.1.p)").frame(width: 26)
                    Text("\(row.1.gf - row.1.ga)").frame(width: 34)
                    Text("\(row.1.pts)").fontWeight(.bold).frame(width: 30)
                }
                .font(.subheadline.monospacedDigit())
                .fontWeight(row.0 == CarTeams.me ? .bold : .regular)
                .listRowBackground(row.0 == CarTeams.me ? lfcRed.opacity(0.15) : nil)
            }
        } footer: {
            Text("İlk 4 Şampiyonlar Ligi'ne gider, son 3 küme düşer.")
        }
    }

    @ViewBuilder
    private var stats: some View {
        Section("Bu sezon") {
            LabeledContent("Maç", value: "\(career.seasonApps)")
            LabeledContent("Gol", value: "\(career.seasonGoals)")
            LabeledContent("Asist", value: "\(career.seasonAssists)")
            LabeledContent("Ortalama puan", value: career.seasonApps == 0 ? "–" : String(format: "%.2f", career.seasonRating))
            LabeledContent("Lig sırası", value: "\(career.leaguePosition).")
        }
        if !career.state.wonThisSeason.isEmpty {
            Section("Bu sezon kazanılan kupalar") {
                ForEach(career.state.wonThisSeason, id: \.self) { Label($0, systemImage: "trophy.fill").foregroundStyle(gold) }
            }
        }
    }
}

// MARK: - History, trophies, awards, national team, transfers

struct HistoryView: View {
    @Environment(CareerStore.self) private var career

    var body: some View {
        List {
            Section {
                ForEach(CareerHistory.seasons.reversed()) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(s.season).font(.headline.monospacedDigit())
                            Text(s.club).foregroundStyle(s.club == "Liverpool" ? lfcRed : .primary).fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "%.1f", s.rating))
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background((s.rating >= 8 ? Color.green : Color.orange).opacity(0.2), in: Capsule())
                        }
                        HStack(spacing: 16) {
                            Label("\(s.apps)", systemImage: "figure.soccer")
                            Label("\(s.goals)", systemImage: "soccerball")
                            Label("\(s.assists)", systemImage: "arrow.turn.up.right")
                        }
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        if !s.trophies.isEmpty {
                            Text("🏆 " + s.trophies.joined(separator: " · "))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(gold)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Kulüp kariyeri")
            } footer: {
                Text("Toplam (bu sezon hariç): \(CareerHistory.clubApps) maç, \(CareerHistory.clubGoals) gol, \(CareerHistory.clubAssists) asist")
            }
            Section("Bu sezon (\(career.state.season))") {
                LabeledContent("Maç · Gol · Asist", value: "\(career.seasonApps) · \(career.seasonGoals) · \(career.seasonAssists)")
            }
        }
        .navigationTitle("Kariyer geçmişi")
    }
}

struct TrophyView: View {
    @Environment(CareerStore.self) private var career

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(CareerHistory.trophies) { t in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(gold.opacity(0.18)).frame(width: 74, height: 74)
                            Image(systemName: t.icon).font(.system(size: 34)).foregroundStyle(gold)
                            if t.seasons.count > 1 {
                                Text("×\(t.seasons.count)")
                                    .font(.caption.weight(.black))
                                    .padding(5)
                                    .background(lfcRed, in: Capsule())
                                    .foregroundStyle(.white)
                                    .offset(x: 30, y: -28)
                            }
                        }
                        Text(t.name).font(.subheadline.weight(.bold)).multilineTextAlignment(.center)
                        Text(t.club).font(.caption).foregroundStyle(.secondary)
                        Text(t.seasons.joined(separator: ", ")).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 170)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                }
                ForEach(career.state.wonThisSeason, id: \.self) { name in
                    VStack(spacing: 8) {
                        Image(systemName: "trophy.fill").font(.system(size: 34)).foregroundStyle(gold)
                        Text(name).font(.subheadline.weight(.bold))
                        Text("Liverpool · \(career.state.season)").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 170)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding()
        }
        .navigationTitle("Kupa dolabı")
    }
}

struct AwardsView: View {
    var body: some View {
        List {
            ForEach(CareerHistory.awards) { a in
                HStack(spacing: 14) {
                    Image(systemName: a.icon)
                        .font(.title2)
                        .foregroundStyle(a.name == "Ballon d'Or" ? gold : lfcRed)
                        .frame(width: 44, height: 44)
                        .background((a.name == "Ballon d'Or" ? gold : lfcRed).opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(a.name).font(.headline)
                        if !a.detail.isEmpty { Text(a.detail).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Text(a.year).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Ödüller")
    }
}

struct NationalView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("🇹🇷").font(.system(size: 44))
                    VStack(alignment: .leading) {
                        Text("Türkiye A Milli Takımı").font(.headline)
                        Text("\(CareerHistory.nationalCaps) maç · \(CareerHistory.nationalGoals) gol").foregroundStyle(.secondary)
                    }
                }
            }
            Section("Öne çıkanlar") {
                ForEach(CareerHistory.nationalNotes, id: \.self) { Text($0) }
            }
            Section("EURO 2024") {
                LabeledContent("Sonuç", value: "Yarı final")
                LabeledContent("Gol", value: "7 · Turnuva gol kralı")
                LabeledContent("Asist", value: "2")
            }
        }
        .navigationTitle("Milli takım")
    }
}

struct TransfersView: View {
    var body: some View {
        List {
            ForEach(CareerHistory.transfers) { t in
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.date).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(t.from)
                        Image(systemName: "arrow.right").foregroundStyle(lfcRed)
                        Text(t.to).fontWeight(.bold)
                    }
                    Text(t.fee).font(.subheadline).foregroundStyle(t.fee.contains("€") ? gold : .secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Transfer geçmişi")
    }
}

// MARK: - Training

struct TrainingView: View {
    @Environment(CareerStore.self) private var career
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?

    var body: some View {
        let s = career.state
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Enerji")
                        ProgressView(value: s.energy, total: 100).tint(.green)
                        Text("\(Int(s.energy))").monospacedDigit()
                    }
                    LabeledContent("Genel güç", value: "\(s.attributes.overall)")
                }
                Section {
                    ForEach(CareerStore.Drill.allCases) { d in
                        Button {
                            if career.train(d) {
                                message = "\(d.rawValue) antrenmanı tamam. Özelliğin biraz arttı."
                                Sfx.play("correct")
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } else {
                                message = "Enerjin yetmiyor. Önce dinlen."
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            }
                        } label: {
                            Label("\(d.rawValue) antrenmanı · 15 enerji", systemImage: d.icon)
                        }
                    }
                } header: {
                    Text("Antrenman")
                } footer: {
                    Text("Her antrenman ilgili özelliği biraz artırır. Maçlar enerji harcar; düşük enerjiyle daha az pozisyon bulur, daha kötü şut atarsın.")
                }
                Section {
                    Button {
                        career.rest()
                        message = "Dinlendin, enerjin yenilendi."
                        Sfx.play("pop")
                    } label: {
                        Label("Dinlen · +35 enerji", systemImage: "bed.double.fill")
                    }
                }
                if let message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Antrenman")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Tamam") { dismiss() } } }
        }
    }
}
