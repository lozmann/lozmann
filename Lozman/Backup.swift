import Foundation
import BackgroundTasks
import UIKit

// MARK: - Background refresh

/// iOS wakes the app now and then (it decides when); we use that to keep
/// reminders topped up, refresh Beşiktaş data and take the daily backup.
enum Background {
    static let id = "com.lozmann.lozman.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refresh)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: id)
        request.earliestBeginDate = Date().addingTimeInterval(4 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule()
        let work = Task { @MainActor in
            Notifier.reschedule(PlanStore.shared.plans)
            Backup.autoBackupIfNeeded()
            await BJKStore.shared.refresh()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}

// MARK: - Backup

struct LozmanBackup: Codable {
    var version = 1
    var created = Date()
    var plans: [Plan]
    var notes: [Note]
    var habits: [Habit]
    var wishes: [WishItem]
    var focusMinutes: [String: Int]
    var profileName: String
}

enum Backup {
    private static let d = UserDefaults.standard

    static var folderName: String? { d.string(forKey: "backupFolderName") }
    static var lastBackup: Date? { d.object(forKey: "lastBackup") as? Date }
    static var hasFolder: Bool { d.data(forKey: "backupFolder") != nil }

    static func snapshot() -> LozmanBackup {
        LozmanBackup(
            plans: PlanStore.shared.plans,
            notes: NotesStore.shared.notes,
            habits: HabitStore.shared.habits,
            wishes: WishStore.shared.items,
            focusMinutes: FocusStore.shared.minutesByDay,
            profileName: ProfileStore.shared.name
        )
    }

    static func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(snapshot())
    }

    /// Remembers a folder the user picked in the Files app (iCloud Drive works too).
    @discardableResult
    static func setFolder(_ url: URL) -> Bool {
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else { return false }
        d.set(bookmark, forKey: "backupFolder")
        d.set(url.lastPathComponent, forKey: "backupFolderName")
        return true
    }

    static func clearFolder() {
        d.removeObject(forKey: "backupFolder")
        d.removeObject(forKey: "backupFolderName")
    }

    private static func folder() -> URL? {
        guard let data = d.data(forKey: "backupFolder") else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            d.set(fresh, forKey: "backupFolder")
        }
        return url
    }

    enum Failure: LocalizedError {
        case noFolder, noAccess
        var errorDescription: String? {
            switch self {
            case .noFolder: return "Önce bir yedek klasörü seç."
            case .noAccess: return "Klasöre ulaşılamadı. Klasörü yeniden seç."
            }
        }
    }

    /// Writes today's backup file and keeps the last 14 days.
    @discardableResult
    static func backupNow() throws -> String {
        guard let dir = folder() else { throw Failure.noFolder }
        let ok = dir.startAccessingSecurityScopedResource()
        defer { if ok { dir.stopAccessingSecurityScopedResource() } }
        let data = try encoded()
        let name = "Lozman-yedek-\(Day.today).json"
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: dir.appendingPathComponent(name), options: .forReplacing, error: &coordError) { url in
            do { try data.write(to: url, options: .atomic) } catch { writeError = error }
        }
        if coordError != nil { throw Failure.noAccess }
        if let writeError { throw writeError }
        // Tidy up old daily files.
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(atPath: dir.path) {
            let backups = files.filter { $0.hasPrefix("Lozman-yedek-") && $0.hasSuffix(".json") }.sorted()
            for old in backups.dropLast(14) {
                try? fm.removeItem(at: dir.appendingPathComponent(old))
            }
        }
        d.set(Date(), forKey: "lastBackup")
        return name
    }

    static func autoBackupIfNeeded() {
        guard hasFolder else { return }
        if let last = lastBackup, Day.key(last) == Day.today { return }
        _ = try? backupNow()
    }

    /// Reads a backup file and replaces everything in the app with it.
    static func restore(from url: URL) throws -> Int {
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let b = try dec.decode(LozmanBackup.self, from: data)
        PlanStore.shared.replaceAll(b.plans)
        NotesStore.shared.replaceAll(b.notes)
        HabitStore.shared.habits = b.habits
        HabitStore.shared.save()
        WishStore.shared.replaceAll(b.wishes)
        FocusStore.shared.replaceMinutes(b.focusMinutes)
        if !b.profileName.isEmpty { ProfileStore.shared.name = b.profileName }
        return b.plans.count + b.notes.count + b.habits.count + b.wishes.count
    }
}
