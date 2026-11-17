import Foundation
import Observation

struct Fixture: Codable, Identifiable, Hashable {
    var date: String
    var time: String
    var home: String
    var away: String
    var comp: String
    var week: Int?
    var id: String { date + home }
    var isHome: Bool { home == "Beşiktaş" }
}

struct MatchResult: Codable, Identifiable {
    var date: String
    var home: String
    var away: String
    var hs: Int
    var awayScore: Int
    var id: String { date + home }

    enum CodingKeys: String, CodingKey {
        case date, home, away, hs, awayScore = "as"
    }

    var outcome: String {
        let mine = home == "Beşiktaş" ? hs : awayScore
        let theirs = home == "Beşiktaş" ? awayScore : hs
        return mine > theirs ? "G" : (mine < theirs ? "M" : "B")
    }
}

struct TableRow: Codable, Identifiable {
    var r: Int
    var t: String
    var o: Int
    var g: Int
    var b: Int
    var m: Int
    var a: Int
    var y: Int
    var av: Int
    var p: Int
    var id: Int { r }
}

struct BJKData: Codable {
    var updated: String
    var source: String
    var fixtures: [Fixture]
    var results: [MatchResult]
    var table: [TableRow]
}

@Observable
final class BJKStore {
    static let shared = BJKStore()

    var data: BJKData?
    var errorText: String?
    var loading = false

    private let remote = URL(string: "https://raw.githubusercontent.com/lozmann/lozmann/main/bjk.json")!
    private let cache = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("bjk.json")

    private init() {
        if let d = try? Data(contentsOf: cache), let decoded = try? JSONDecoder().decode(BJKData.self, from: d) {
            data = decoded
        } else if let url = Bundle.main.url(forResource: "bjk", withExtension: "json"),
                  let d = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(BJKData.self, from: d) {
            data = decoded
        }
    }

    @MainActor
    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            var request = URLRequest(url: remote)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (d, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let decoded = try JSONDecoder().decode(BJKData.self, from: d)
            if decoded.updated >= (data?.updated ?? "") {
                data = decoded
                try? d.write(to: cache, options: .atomic)
            }
            errorText = nil
        } catch {
            errorText = "Güncel veriye ulaşılamadı. Kayıtlı veriler gösteriliyor."
        }
    }

    var upcoming: [Fixture] {
        let today = Day.today
        return (data?.fixtures ?? []).filter { $0.date >= today }.sorted { $0.date < $1.date }
    }

    var nextMatch: Fixture? { upcoming.first }
}
