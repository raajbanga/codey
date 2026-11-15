import Foundation

/// Where the pull cursor (largest server_updated_at seen) is kept, per account.
struct SyncCursorStore {
    var defaults: UserDefaults = .standard

    func cursor(for userID: UUID) -> Date? {
        defaults.object(forKey: "codey.sync.pullCursor.\(userID.uuidString)") as? Date
    }

    func setCursor(_ date: Date?, for userID: UUID) {
        defaults.set(date, forKey: "codey.sync.pullCursor.\(userID.uuidString)")
    }

    func lastSyncedAt(for userID: UUID) -> Date? {
        defaults.object(forKey: "codey.sync.lastSyncedAt.\(userID.uuidString)") as? Date
    }

    func setLastSyncedAt(_ date: Date?, for userID: UUID) {
        defaults.set(date, forKey: "codey.sync.lastSyncedAt.\(userID.uuidString)")
    }

    // FR-61: study progress has its own pull cursor and a push marker
    // (local rows reviewed after it haven't been pushed yet).

    func progressCursor(for userID: UUID) -> Date? {
        defaults.object(forKey: "codey.sync.progressCursor.\(userID.uuidString)") as? Date
    }

    func setProgressCursor(_ date: Date?, for userID: UUID) {
        defaults.set(date, forKey: "codey.sync.progressCursor.\(userID.uuidString)")
    }

    func progressPushedAt(for userID: UUID) -> Date? {
        defaults.object(forKey: "codey.sync.progressPushedAt.\(userID.uuidString)") as? Date
    }

    func setProgressPushedAt(_ date: Date?, for userID: UUID) {
        defaults.set(date, forKey: "codey.sync.progressPushedAt.\(userID.uuidString)")
    }

    /// S43 history (quiz answers, days, badges) has its own push marker, so
    /// the first sync after the update sends the whole history once, not
    /// only what changed since the last progress push.
    func historyPushedAt(for userID: UUID) -> Date? {
        defaults.object(forKey: "codey.sync.historyPushedAt.\(userID.uuidString)") as? Date
    }

    func setHistoryPushedAt(_ date: Date?, for userID: UUID) {
        defaults.set(date, forKey: "codey.sync.historyPushedAt.\(userID.uuidString)")
    }
}
