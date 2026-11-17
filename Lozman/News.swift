import SwiftUI
import Observation

enum NewsFeed: String, CaseIterable, Identifiable {
    case trends = "En çok arananlar"
    case top = "Gündem"
    case sport = "Spor"
    case bbc = "BBC Türkçe"

    var id: String { rawValue }

    var url: URL? {
        switch self {
        case .trends: return URL(string: "https://trends.google.com/trending/rss?geo=TR")
        case .top: return URL(string: "https://news.google.com/rss?hl=tr&gl=TR&ceid=TR:tr")
        case .sport: return URL(string: "https://news.google.com/rss/headlines/section/topic/SPORTS?hl=tr&gl=TR&ceid=TR:tr")
        case .bbc: return URL(string: "https://feeds.bbci.co.uk/turkce/rss.xml")
        }
    }

    var icon: String {
        switch self {
        case .trends: return "chart.line.uptrend.xyaxis"
        case .top: return "newspaper"
        case .sport: return "soccerball"
        case .bbc: return "globe.europe.africa"
        }
    }
}

struct FeedItem: Identifiable {
    let id = UUID()
    var title = ""
    var link = ""
    var source = ""
    var date: Date?
    var traffic = ""
    var newsTitle = ""
    var newsURL = ""
}

final class RSSReader: NSObject, XMLParserDelegate {
    private var items: [FeedItem] = []
    private var current: FeedItem?
    private var text = ""
    private var gotNews = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    func parse(_ data: Data) -> [FeedItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        text = ""
        if elementName == "item" {
            current = FeedItem()
            gotNews = false
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard current != nil else { return }
        switch elementName {
        case "title": current?.title = value
        case "link": current?.link = value
        case "source": current?.source = value
        case "pubDate": current?.date = Self.dateFormatter.date(from: value)
        case "ht:approx_traffic": current?.traffic = value
        case "ht:news_item_title": if !gotNews { current?.newsTitle = value }
        case "ht:news_item_url":
            if !gotNews { current?.newsURL = value; gotNews = true }
        case "item":
            if var item = current {
                // Google News titles end with " - Source".
                if item.source.isEmpty, let r = item.title.range(of: " - ", options: .backwards) {
                    item.source = String(item.title[r.upperBound...])
                    item.title = String(item.title[..<r.lowerBound])
                }
                items.append(item)
            }
            current = nil
        default: break
        }
        text = ""
    }
}

@Observable
final class NewsStore {
    static let shared = NewsStore()

    var items: [NewsFeed: [FeedItem]] = [:]
    var updated: [NewsFeed: Date] = [:]
    var loading = false
    var errorText: String?

    @MainActor
    func load(_ feed: NewsFeed, force: Bool = false) async {
        if !force, let last = updated[feed], Date().timeIntervalSince(last) < 600 { return }
        guard let url = feed.url else { return }
        loading = true
        defer { loading = false }
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let parsed = RSSReader().parse(data)
            guard !parsed.isEmpty else { throw URLError(.cannotParseResponse) }
            items[feed] = parsed
            updated[feed] = Date()
            errorText = nil
        } catch {
            errorText = "Haberlere ulaşılamadı. İnternet bağlantını kontrol edip aşağı çekerek yenile."
        }
    }
}

struct NewsView: View {
    @Environment(NewsStore.self) private var news
    @Environment(\.openURL) private var openURL
    @State private var feed: NewsFeed = .trends

    var body: some View {
        let list = news.items[feed] ?? []
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(NewsFeed.allCases) { f in
                            Button {
                                feed = f
                            } label: {
                                Label(f.rawValue, systemImage: f.icon)
                                    .font(.subheadline.weight(feed == f ? .semibold : .regular))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(feed == f ? Color.loz : Color(.secondarySystemBackground), in: Capsule())
                                    .foregroundStyle(feed == f ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if let e = news.errorText, list.isEmpty {
                Text(e).foregroundStyle(.secondary)
            } else if list.isEmpty && news.loading {
                HStack { ProgressView(); Text("Yükleniyor…").foregroundStyle(.secondary) }
            }

            Section {
                ForEach(Array(list.prefix(40).enumerated()), id: \.element.id) { index, item in
                    Button {
                        open(item)
                    } label: {
                        if feed == .trends {
                            trendRow(index + 1, item)
                        } else {
                            newsRow(item)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                if feed == .trends {
                    Text("Türkiye'de son saatlerde Google'da en çok aranan konular. X (Twitter) gündemi ücretsiz ve izinli bir yolla alınamadığı için onun yerine bu liste gösteriliyor. Habere dokununca tarayıcıda açılır.")
                } else if let d = news.updated[feed] {
                    Text("Son güncelleme \(WorkClock.format(WorkClock.minutes(d))). Habere dokununca tarayıcıda açılır.")
                }
            }
        }
        .navigationTitle("Gündem")
        .refreshable { await news.load(feed, force: true) }
        .task(id: feed) { await news.load(feed) }
    }

    private func open(_ item: FeedItem) {
        let target = !item.newsURL.isEmpty ? item.newsURL : item.link
        if feed == .trends, item.newsURL.isEmpty,
           let q = item.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.google.com/search?q=\(q)") {
            openURL(url)
        } else if let url = URL(string: target) {
            openURL(url)
        }
    }

    private func trendRow(_ rank: Int, _ item: FeedItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(rank <= 3 ? Color.loz : Color.secondary)
                .frame(width: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.title).font(.headline)
                    Spacer()
                    if !item.traffic.isEmpty {
                        Text(item.traffic + " arama")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !item.newsTitle.isEmpty {
                    Text(item.newsTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func newsRow(_ item: FeedItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title).font(.body.weight(.medium)).lineLimit(3)
            HStack(spacing: 6) {
                if !item.source.isEmpty { Text(item.source) }
                if let d = item.date { Text("· " + relative(d)) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func relative(_ d: Date) -> String {
        let mins = Int(Date().timeIntervalSince(d) / 60)
        if mins < 1 { return "şimdi" }
        if mins < 60 { return "\(mins) dk önce" }
        if mins < 1440 { return "\(mins / 60) sa önce" }
        return "\(mins / 1440) gün önce"
    }
}
