import Foundation
import Observation

// MARK: - Static career history (Berat Dirgen, 2018–2026)

struct CarSeason: Identifiable {
    let season: String
    let club: String
    let league: String
    let apps: Int
    let goals: Int
    let assists: Int
    let rating: Double
    let trophies: [String]
    var id: String { season + club }
}

struct CarTrophy: Identifiable {
    let name: String
    let icon: String
    let seasons: [String]
    let club: String
    var id: String { name + club }
}

struct CarAward: Identifiable {
    let year: String
    let name: String
    let detail: String
    let icon: String
    var id: String { year + name }
}

struct CarTransfer: Identifiable {
    let date: String
    let from: String
    let to: String
    let fee: String
    var id: String { date }
}

enum CareerHistory {
    static let name = "Berat Dirgen"
    static let shortName = "DİRGEN"
    static let birthYear = 2002
    static let number = 10
    static let position = "SĞK / SF"
    static let nation = "Türkiye"
    static let foot = "Sol"
    static let height = "1,81 m"

    static let seasons: [CarSeason] = [
        CarSeason(season: "2018-19", club: "Beşiktaş", league: "Süper Lig", apps: 9, goals: 2, assists: 1, rating: 6.8, trophies: []),
        CarSeason(season: "2019-20", club: "Beşiktaş", league: "Süper Lig", apps: 31, goals: 13, assists: 7, rating: 7.3, trophies: []),
        CarSeason(season: "2020-21", club: "Beşiktaş", league: "Süper Lig", apps: 38, goals: 30, assists: 12, rating: 8.1, trophies: ["Süper Lig", "Türkiye Kupası"]),
        CarSeason(season: "2021-22", club: "Liverpool", league: "Premier League", apps: 47, goals: 21, assists: 12, rating: 7.6, trophies: ["FA Cup"]),
        CarSeason(season: "2022-23", club: "Liverpool", league: "Premier League", apps: 51, goals: 29, assists: 14, rating: 8.0, trophies: ["Premier League", "Community Shield"]),
        CarSeason(season: "2023-24", club: "Liverpool", league: "Premier League", apps: 54, goals: 38, assists: 16, rating: 8.4, trophies: ["Şampiyonlar Ligi", "Premier League", "Community Shield"]),
        CarSeason(season: "2024-25", club: "Liverpool", league: "Premier League", apps: 49, goals: 31, assists: 15, rating: 8.2, trophies: ["UEFA Süper Kupa", "FA Cup", "Premier League"]),
        CarSeason(season: "2025-26", club: "Liverpool", league: "Premier League", apps: 46, goals: 26, assists: 13, rating: 7.9, trophies: [])
    ]

    static let trophies: [CarTrophy] = [
        CarTrophy(name: "UEFA Şampiyonlar Ligi", icon: "trophy.fill", seasons: ["2023-24"], club: "Liverpool"),
        CarTrophy(name: "Premier League", icon: "crown.fill", seasons: ["2022-23", "2023-24", "2024-25"], club: "Liverpool"),
        CarTrophy(name: "FA Cup", icon: "cup.and.saucer.fill", seasons: ["2021-22", "2024-25"], club: "Liverpool"),
        CarTrophy(name: "Community Shield", icon: "shield.fill", seasons: ["2022", "2023"], club: "Liverpool"),
        CarTrophy(name: "UEFA Süper Kupa", icon: "star.circle.fill", seasons: ["2024"], club: "Liverpool"),
        CarTrophy(name: "Süper Lig", icon: "crown.fill", seasons: ["2020-21"], club: "Beşiktaş"),
        CarTrophy(name: "Türkiye Kupası", icon: "trophy.fill", seasons: ["2020-21"], club: "Beşiktaş")
    ]

    static let awards: [CarAward] = [
        CarAward(year: "2024", name: "Ballon d'Or", detail: "Dünyanın en iyi futbolcusu · Şampiyonlar Ligi, Premier League ve EURO 2024 gol krallığıyla", icon: "circle.hexagongrid.fill"),
        CarAward(year: "2024", name: "EURO 2024 Gol Kralı", detail: "7 gol · Türkiye yarı finale çıktı", icon: "soccerball"),
        CarAward(year: "2023-24", name: "Şampiyonlar Ligi Sezonun Oyuncusu", detail: "13 maç, 11 gol, 5 asist", icon: "star.fill"),
        CarAward(year: "2023-24", name: "Premier League Altın Ayakkabı", detail: "Ligde 27 gol", icon: "shoe.fill"),
        CarAward(year: "2023-24", name: "Premier League Sezonun Oyuncusu", detail: "", icon: "person.fill.checkmark"),
        CarAward(year: "2024", name: "PFA Yılın Oyuncusu", detail: "Oyuncuların oylarıyla", icon: "person.3.fill"),
        CarAward(year: "2021", name: "Golden Boy", detail: "Avrupa'nın en iyi genç oyuncusu", icon: "sparkles"),
        CarAward(year: "2020-21", name: "Süper Lig Gol Kralı", detail: "Ligde 24 gol · Beşiktaş şampiyon", icon: "soccerball")
    ]

    static let transfers: [CarTransfer] = [
        CarTransfer(date: "2015", from: "—", to: "Gençlerbirliği altyapısı", fee: "Altyapı"),
        CarTransfer(date: "Temmuz 2018", from: "Gençlerbirliği U17", to: "Beşiktaş", fee: "İlk profesyonel sözleşme"),
        CarTransfer(date: "Ağustos 2021", from: "Beşiktaş", to: "Liverpool", fee: "€56 milyon · Türk futbol tarihinin rekoru")
    ]

    static let nationalCaps = 54
    static let nationalGoals = 33
    static let nationalNotes = [
        "A Milli Takım ilk maç: Eylül 2020",
        "EURO 2020 grup aşaması",
        "EURO 2024 yarı final · turnuva gol kralı (7 gol)",
        "Türkiye A Milli Takım tarihinin en golcü oyuncularından"
    ]

    static var clubApps: Int { seasons.reduce(0) { $0 + $1.apps } }
    static var clubGoals: Int { seasons.reduce(0) { $0 + $1.goals } }
    static var clubAssists: Int { seasons.reduce(0) { $0 + $1.assists } }
    static var trophyCount: Int { trophies.reduce(0) { $0 + $1.seasons.count } }
}

// MARK: - Live season

struct CarTeam {
    let name: String
    let rating: Int
}

enum CarTeams {
    static let me = "Liverpool"
    static let league: [CarTeam] = [
        CarTeam(name: "Liverpool", rating: 87), CarTeam(name: "Arsenal", rating: 85), CarTeam(name: "Manchester City", rating: 86),
        CarTeam(name: "Chelsea", rating: 83), CarTeam(name: "Manchester United", rating: 80), CarTeam(name: "Tottenham", rating: 80),
        CarTeam(name: "Newcastle", rating: 81), CarTeam(name: "Aston Villa", rating: 80), CarTeam(name: "Brighton", rating: 77),
        CarTeam(name: "West Ham", rating: 76), CarTeam(name: "Crystal Palace", rating: 76), CarTeam(name: "Brentford", rating: 75),
        CarTeam(name: "Fulham", rating: 75), CarTeam(name: "Everton", rating: 75), CarTeam(name: "Wolves", rating: 74),
        CarTeam(name: "Nottingham Forest", rating: 77), CarTeam(name: "Bournemouth", rating: 76), CarTeam(name: "Leeds United", rating: 73),
        CarTeam(name: "Sunderland", rating: 72), CarTeam(name: "Burnley", rating: 71)
    ]
    static let europe: [CarTeam] = [
        CarTeam(name: "Real Madrid", rating: 88), CarTeam(name: "Barcelona", rating: 87), CarTeam(name: "Bayern Münih", rating: 87),
        CarTeam(name: "Paris Saint-Germain", rating: 87), CarTeam(name: "Inter", rating: 85), CarTeam(name: "Atlético Madrid", rating: 84),
        CarTeam(name: "Bayer Leverkusen", rating: 83), CarTeam(name: "Borussia Dortmund", rating: 82), CarTeam(name: "Napoli", rating: 82),
        CarTeam(name: "Juventus", rating: 82), CarTeam(name: "Milan", rating: 81), CarTeam(name: "Benfica", rating: 80),
        CarTeam(name: "Galatasaray", rating: 79), CarTeam(name: "Porto", rating: 79), CarTeam(name: "Ajax", rating: 77)
    ]

    static func rating(_ name: String) -> Int {
        (league + europe).first { $0.name == name }?.rating ?? 78
    }
}

struct CarFixture: Codable, Identifiable {
    var id = UUID()
    var comp: String          // "PL" or "UCL"
    var round: String
    var opponent: String
    var home: Bool
    var played = false
    var goalsFor = 0
    var goalsAgainst = 0
    var myGoals = 0
    var myAssists = 0
    var rating = 0.0

    var compName: String { comp == "PL" ? "Premier League" : "Şampiyonlar Ligi" }
    var won: Bool { goalsFor > goalsAgainst }
}

struct CarTableRow: Codable {
    var p = 0, w = 0, d = 0, l = 0, gf = 0, ga = 0
    var pts: Int { w * 3 + d }
    mutating func add(_ f: Int, _ a: Int) {
        p += 1; gf += f; ga += a
        if f > a { w += 1 } else if f == a { d += 1 } else { l += 1 }
    }
}

struct CarAttributes: Codable {
    var pac = 92.0, sho = 93.0, pas = 86.0, dri = 92.0, def = 41.0, phy = 80.0
    var overall: Int {
        Int((pac * 0.18 + sho * 0.30 + pas * 0.15 + dri * 0.25 + phy * 0.12).rounded())
    }
}

struct CareerState: Codable {
    var season = "2026-27"
    var fixtures: [CarFixture] = []
    var table: [String: CarTableRow] = [:]
    var uclPoints = 0
    var uclStage = "Lig aşaması"
    var uclOut = false
    var attributes = CarAttributes()
    var energy = 100.0
    var morale = 80.0
    var form: [Double] = []
    var wonThisSeason: [String] = []
    var seasonOver = false
}

enum CarSim {
    /// Poisson goals from two ratings.
    static func goals(_ a: Int, vs b: Int, home: Bool, factor: Double = 1) -> Int {
        let lambda = max(0.15, (1.35 * pow(1.13, Double(a - b) / 2) + (home ? 0.25 : 0)) * factor)
        let l = exp(-lambda)
        var k = 0
        var p = 1.0
        repeat {
            k += 1
            p *= Double.random(in: 0...1)
        } while p > l && k < 10
        return k - 1
    }
}

@Observable
final class CareerStore {
    static let shared = CareerStore()

    var state = CareerState()

    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("career.json")

    private init() {
        if let data = try? Data(contentsOf: url),
           let s = try? JSONDecoder().decode(CareerState.self, from: data) {
            state = s
        } else {
            newSeason()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: Season setup

    func newSeason() {
        var s = CareerState()
        s.attributes = state.attributes
        s.season = state.fixtures.isEmpty ? "2026-27" : nextSeasonLabel(state.season)
        for t in CarTeams.league { s.table[t.name] = CarTableRow() }

        let opponents = CarTeams.league.map(\.name).filter { $0 != CarTeams.me }.shuffled()
        var pl: [CarFixture] = []
        for (i, o) in opponents.enumerated() {
            pl.append(CarFixture(comp: "PL", round: "\(i + 1). hafta", opponent: o, home: i % 2 == 0))
        }
        for (i, o) in opponents.enumerated() {
            pl.append(CarFixture(comp: "PL", round: "\(i + 20). hafta", opponent: o, home: i % 2 != 0))
        }
        let ucl = CarTeams.europe.shuffled().prefix(8).enumerated().map { i, t in
            CarFixture(comp: "UCL", round: "Lig aşaması \(i + 1)", opponent: t.name, home: i % 2 == 0)
        }
        // A Champions League night roughly every fourth week.
        var all: [CarFixture] = []
        var u = 0
        for (i, f) in pl.enumerated() {
            all.append(f)
            if (i + 1) % 3 == 0 && u < ucl.count {
                all.append(ucl[u])
                u += 1
            }
        }
        s.fixtures = all
        state = s
        save()
    }

    private func nextSeasonLabel(_ s: String) -> String {
        let parts = s.split(separator: "-")
        guard let a = Int(parts.first ?? "") else { return s }
        return "\(a + 1)-\(String(a + 2).suffix(2))"
    }

    var nextFixture: CarFixture? { state.fixtures.first { !$0.played } }

    var seasonApps: Int { state.fixtures.filter(\.played).count }
    var seasonGoals: Int { state.fixtures.reduce(0) { $0 + $1.myGoals } }
    var seasonAssists: Int { state.fixtures.reduce(0) { $0 + $1.myAssists } }
    var seasonRating: Double {
        let r = state.fixtures.filter(\.played).map(\.rating)
        return r.isEmpty ? 0 : r.reduce(0, +) / Double(r.count)
    }

    var sortedTable: [(String, CarTableRow)] {
        state.table.sorted { a, b in
            if a.value.pts != b.value.pts { return a.value.pts > b.value.pts }
            let ga = a.value.gf - a.value.ga, gb = b.value.gf - b.value.ga
            if ga != gb { return ga > gb }
            return a.value.gf > b.value.gf
        }
    }

    var leaguePosition: Int { (sortedTable.firstIndex { $0.0 == CarTeams.me } ?? 0) + 1 }

    var totalGoals: Int { CareerHistory.clubGoals + seasonGoals }
    var totalAssists: Int { CareerHistory.clubAssists + seasonAssists }
    var totalApps: Int { CareerHistory.clubApps + seasonApps }
    var totalTrophies: Int { CareerHistory.trophyCount + state.wonThisSeason.count }

    var marketValue: Int {
        let ovr = state.attributes.overall
        let formAvg = state.form.isEmpty ? 7.5 : state.form.suffix(5).reduce(0, +) / Double(min(5, state.form.count))
        return max(60, Int(Double(ovr - 80) * 14 + (formAvg - 7) * 20 + 30))
    }

    // MARK: Results

    /// Records a finished match and moves the season on.
    func finish(_ id: UUID, goalsFor: Int, goalsAgainst: Int, myGoals: Int, myAssists: Int, rating: Double) {
        guard let i = state.fixtures.firstIndex(where: { $0.id == id }) else { return }
        state.fixtures[i].played = true
        state.fixtures[i].goalsFor = goalsFor
        state.fixtures[i].goalsAgainst = goalsAgainst
        state.fixtures[i].myGoals = myGoals
        state.fixtures[i].myAssists = myAssists
        state.fixtures[i].rating = rating
        let f = state.fixtures[i]

        state.form.append(rating)
        if state.form.count > 10 { state.form.removeFirst() }
        state.energy = max(5, state.energy - 22)
        state.morale = min(100, max(10, state.morale + (f.won ? 6 : (goalsFor == goalsAgainst ? 0 : -8)) + (rating >= 8 ? 4 : 0)))

        if f.comp == "PL" {
            state.table[CarTeams.me, default: CarTableRow()].add(goalsFor, goalsAgainst)
            state.table[f.opponent, default: CarTableRow()].add(goalsAgainst, goalsFor)
            simulateOtherLeagueGames(excluding: f.opponent)
        } else {
            updateEurope(after: f)
        }
        checkSeasonEnd()
        save()
    }

    private func simulateOtherLeagueGames(excluding opponent: String) {
        let others = CarTeams.league.filter { $0.name != CarTeams.me && $0.name != opponent }.shuffled()
        var k = 0
        while k + 1 < others.count {
            let a = others[k], b = others[k + 1]
            let ga = CarSim.goals(a.rating, vs: b.rating, home: true)
            let gb = CarSim.goals(b.rating, vs: a.rating, home: false)
            state.table[a.name, default: CarTableRow()].add(ga, gb)
            state.table[b.name, default: CarTableRow()].add(gb, ga)
            k += 2
        }
    }

    private func updateEurope(after f: CarFixture) {
        if f.round.hasPrefix("Lig aşaması") {
            state.uclPoints += f.won ? 3 : (f.goalsFor == f.goalsAgainst ? 1 : 0)
            let leaguePhaseDone = !state.fixtures.contains { $0.comp == "UCL" && $0.round.hasPrefix("Lig aşaması") && !$0.played }
            if leaguePhaseDone {
                if state.uclPoints >= 12 {
                    addKnockout("Son 16")
                } else {
                    state.uclOut = true
                    state.uclStage = "Lig aşamasında elendi"
                }
            }
            return
        }
        // Knockouts are single matches here; a draw goes to penalties.
        let through = f.goalsFor > f.goalsAgainst || (f.goalsFor == f.goalsAgainst && Bool.random())
        if !through {
            state.uclOut = true
            state.uclStage = "\(f.round)'da elendi"
            return
        }
        switch f.round {
        case "Son 16": addKnockout("Çeyrek final")
        case "Çeyrek final": addKnockout("Yarı final")
        case "Yarı final": addKnockout("Final")
        case "Final":
            state.uclStage = "Şampiyon"
            state.wonThisSeason.append("Şampiyonlar Ligi")
        default: break
        }
    }

    private func addKnockout(_ round: String) {
        state.uclStage = round
        let used = Set(state.fixtures.filter { $0.comp == "UCL" }.map(\.opponent))
        let pool = CarTeams.europe.filter { !used.contains($0.name) }.sorted { $0.rating > $1.rating }
        let opp = (round == "Final" ? pool.first : pool.prefix(6).randomElement()) ?? CarTeams.europe[0]
        let fixture = CarFixture(comp: "UCL", round: round, opponent: opp.name, home: round != "Final" && Bool.random())
        // Insert a few weeks ahead so the season keeps mixing competitions.
        if let next = state.fixtures.firstIndex(where: { !$0.played }) {
            let at = min(state.fixtures.count, next + 3)
            state.fixtures.insert(fixture, at: at)
        } else {
            state.fixtures.append(fixture)
        }
    }

    private func checkSeasonEnd() {
        guard !state.seasonOver, !state.fixtures.contains(where: { !$0.played }) else { return }
        state.seasonOver = true
        if leaguePosition == 1 { state.wonThisSeason.append("Premier League") }
    }

    // MARK: Training

    enum Drill: String, CaseIterable, Identifiable {
        case shooting = "Şut", dribbling = "Top sürme", passing = "Pas", pace = "Sürat", strength = "Güç"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .shooting: return "scope"
            case .dribbling: return "figure.soccer"
            case .passing: return "arrow.triangle.branch"
            case .pace: return "hare.fill"
            case .strength: return "dumbbell.fill"
            }
        }
    }

    @discardableResult
    func train(_ d: Drill) -> Bool {
        guard state.energy >= 15 else { return false }
        state.energy -= 15
        let gain = Double.random(in: 0.15...0.45)
        switch d {
        case .shooting: state.attributes.sho = min(99, state.attributes.sho + gain)
        case .dribbling: state.attributes.dri = min(99, state.attributes.dri + gain)
        case .passing: state.attributes.pas = min(99, state.attributes.pas + gain)
        case .pace: state.attributes.pac = min(99, state.attributes.pac + gain)
        case .strength: state.attributes.phy = min(99, state.attributes.phy + gain)
        }
        save()
        return true
    }

    func rest() {
        state.energy = min(100, state.energy + 35)
        state.morale = min(100, state.morale + 3)
        save()
    }
}
