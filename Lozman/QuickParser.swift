import Foundation

/// Understands Turkish quick-add text such as
/// "yarın 15:00 dişçi", "cuma 10'da toplantı", "her gün 21:30 duş al", "25 kasım akşam 8 düğün".
struct ParsedPlan {
    var title: String
    var date: String
    var time: String
    var repeatRule: RepeatRule
    var category: PlanCategory
    var understood: [String]
}

enum QuickParser {
    private static let tr = Locale(identifier: "tr_TR")
    private static let weekdays: [(String, Int)] = [
        ("pazartesi", 2), ("salı", 3), ("çarşamba", 4), ("perşembe", 5), ("cumartesi", 7), ("cuma", 6), ("pazar", 1)
    ]
    private static let months = ["ocak", "şubat", "mart", "nisan", "mayıs", "haziran", "temmuz", "ağustos", "eylül", "ekim", "kasım", "aralık"]

    static func parse(_ raw: String, now: Date = Date(), defaultCategory: PlanCategory = .personal) -> ParsedPlan {
        let original = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = original.lowercased(with: tr)
        // Work on the lowercased text; if lengths match we can cut the same ranges from the original.
        let sameShape = (lower as NSString).length == (original as NSString).length
        var work = lower as NSString
        var keep = (sameShape ? original : lower) as NSString
        var notes: [String] = []
        let cal = Calendar.current
        let today = Day.key(now)

        func take(_ pattern: String) -> NSTextCheckingResult? {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
            guard let m = re.firstMatch(in: work as String, range: NSRange(location: 0, length: work.length)) else { return nil }
            return m
        }
        func cut(_ m: NSTextCheckingResult) {
            let blank = String(repeating: " ", count: m.range.length)
            work = work.replacingCharacters(in: m.range, with: blank) as NSString
            keep = keep.replacingCharacters(in: m.range, with: blank) as NSString
        }
        func group(_ m: NSTextCheckingResult, _ i: Int) -> String? {
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : work.substring(with: r)
        }
        func nextWeekday(_ wd: Int, from day: String) -> String {
            let cur = cal.component(.weekday, from: Day.date(day))
            let delta = (wd - cur + 7) % 7
            return Day.add(day, delta)
        }

        var date = today
        var dateSet = false
        var repeatRule = RepeatRule.none

        // Repeats
        if let m = take("\\b(her ?gün|hergün)\\b") {
            repeatRule = .daily; cut(m); notes.append("Her gün")
        } else if let m = take("\\bhafta ?içi( her ?gün)?\\b") {
            repeatRule = .weekdays; cut(m); notes.append("Hafta içi")
        } else if let m = take("\\bher (pazartesi|salı|çarşamba|perşembe|cumartesi|cuma|pazar)\\w*") {
            let name = group(m, 1) ?? ""
            if let wd = weekdays.first(where: { $0.0 == name })?.1 {
                date = nextWeekday(wd, from: today); dateSet = true
            }
            repeatRule = .weekly; cut(m); notes.append("Her hafta")
        } else if let m = take("\\bher hafta\\b") {
            repeatRule = .weekly; cut(m); notes.append("Her hafta")
        } else if let m = take("\\bher ay\\b") {
            repeatRule = .monthly; cut(m); notes.append("Her ay")
        } else if let m = take("\\bher (yıl|sene)\\b") {
            repeatRule = .yearly; cut(m); notes.append("Her yıl")
        }

        // Dates
        if !dateSet {
            if let m = take("\\b(öbür ?gün|yarından sonra)\\b") {
                date = Day.add(today, 2); dateSet = true; cut(m)
            } else if let m = take("\\byarın\\w*") {
                date = Day.add(today, 1); dateSet = true; cut(m)
            } else if let m = take("\\bbugün\\w*") {
                dateSet = true; cut(m)
            } else if let m = take("\\b(\\d{1,2}) (ocak|şubat|mart|nisan|mayıs|haziran|temmuz|ağustos|eylül|ekim|kasım|aralık)\\w*( (\\d{4}))?") {
                let d = Int(group(m, 1) ?? "") ?? 1
                let mon = (months.firstIndex(of: group(m, 2) ?? "") ?? 0) + 1
                var y = Int(group(m, 4) ?? "") ?? cal.component(.year, from: now)
                var comps = DateComponents(year: y, month: mon, day: d)
                if let dt = cal.date(from: comps), Day.key(dt) < today, group(m, 4) == nil {
                    y += 1
                    comps.year = y
                }
                if let dt = cal.date(from: comps) { date = Day.key(dt); dateSet = true }
                cut(m)
            } else if let m = take("\\b(\\d{1,2})/(\\d{1,2})(/(\\d{2,4}))?\\b") {
                let d = Int(group(m, 1) ?? "") ?? 1
                let mon = Int(group(m, 2) ?? "") ?? 1
                var y = Int(group(m, 4) ?? "") ?? cal.component(.year, from: now)
                if y < 100 { y += 2000 }
                if let dt = cal.date(from: DateComponents(year: y, month: mon, day: d)) { date = Day.key(dt); dateSet = true }
                cut(m)
            } else if let m = take("\\b(\\d{1,2}) gün sonra\\b") {
                date = Day.add(today, Int(group(m, 1) ?? "") ?? 0); dateSet = true; cut(m)
            } else if let m = take("\\bhaftaya (pazartesi|salı|çarşamba|perşembe|cumartesi|cuma|pazar)\\w*") {
                if let wd = weekdays.first(where: { $0.0 == group(m, 1) })?.1 {
                    date = Day.add(nextWeekday(wd, from: today), 7); dateSet = true
                }
                cut(m)
            } else if let m = take("\\b(pazartesi|salı|çarşamba|perşembe|cumartesi|cuma|pazar)\\w*( günü)?") {
                if let wd = weekdays.first(where: { $0.0 == group(m, 1) })?.1 {
                    date = nextWeekday(wd, from: today); dateSet = true
                }
                cut(m)
            } else if let m = take("\\bhaftaya\\b") {
                date = Day.add(today, 7); dateSet = true; cut(m)
            }
        }

        // Part of day
        var period: String?
        if let m = take("\\b(sabah|öğleden sonra|öğle(n|den)?|akşam|gece)\\w*") {
            period = group(m, 1)
            cut(m)
        }

        // Time
        var hour: Int?
        var minute = 0
        if let m = take("\\b(?:saat )?(\\d{1,2})[:.](\\d{2})(?:'?(?:de|da|te|ta))?\\b") {
            hour = Int(group(m, 1) ?? ""); minute = Int(group(m, 2) ?? "") ?? 0; cut(m)
        } else if let m = take("\\bsaat (\\d{1,2})(?:'?(?:de|da|te|ta))?\\b") {
            hour = Int(group(m, 1) ?? ""); cut(m)
        } else if let m = take("\\b(\\d{1,2})'?(?:de|da|te|ta)\\b") {
            hour = Int(group(m, 1) ?? ""); cut(m)
        } else if period != nil, let m = take("\\b(\\d{1,2})\\b") {
            hour = Int(group(m, 1) ?? ""); cut(m)
        }
        if var h = hour, h <= 23, minute <= 59 {
            let p = period ?? ""
            if p == "sabah" {
                if h == 12 { h = 0 }
            } else if p == "öğleden sonra" || p == "akşam" {
                if h < 12 { h += 12 }
            } else if p == "gece" {
                if h >= 5 && h < 12 { h += 12 }
            } else if p.hasPrefix("öğle") {
                if h < 6 { h += 12 }
            } else if h >= 1 && h <= 7 {
                h += 12   // "3'te" usually means 15:00
            }
            hour = h
        } else if hour == nil, let p = period {
            switch p {
            case "sabah": hour = 9
            case "akşam": hour = 19
            case "gece": hour = 22
            default: hour = 13
            }
        } else {
            hour = nil
        }
        let time = hour.map { String(format: "%02d:%02d", $0, minute) } ?? ""

        // Category guess
        var category = defaultCategory
        let categoryWords: [(String, PlanCategory)] = [
            ("toplantı|rapor|yazı|resmi|mesai|ofis|müdür|başkan|sunum|e-?posta|mail|görev", .work),
            ("ödev|ders|sınav|kurs|hoca|çalış", .homework),
            ("maç|konser|düğün|doğum günü|etkinlik|sinema|tiyatro|parti|nişan", .event),
            ("spor|koşu|duş|su iç|uyku|kitap|meditasyon", .routine)
        ]
        for (pattern, cat) in categoryWords {
            if (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: lower, range: NSRange(location: 0, length: (lower as NSString).length)) != nil {
                category = cat
                break
            }
        }

        // Title: what is left, tidied up.
        var title = (keep as String)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters))
        if title.isEmpty { title = original }
        if let first = title.first, first.isLowercase {
            title = String(first).uppercased(with: tr) + title.dropFirst()
        }

        if dateSet { notes.insert(Day.nice(date), at: 0) }
        if !time.isEmpty { notes.append(time) }
        return ParsedPlan(title: title, date: date, time: time, repeatRule: repeatRule, category: category, understood: notes)
    }
}
