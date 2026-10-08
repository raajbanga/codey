import Foundation

/// Where the pull cursor (largest server_updated_at seen) is kept, per account.
struct SyncCursorStore {
    var defaults: UserDefaults = .standard

    func cursor(for userID: UUID) -> Date? {
        defaults.object(forKey: key(userID)) as? Date
    }

    func setCursor(_ date: Date?, for userID: UUID) {
        defaults.set(date, forKey: key(userID))
    }

    func lastSyncedAt(for userID: UUID) -> Date? {
        defaults.object(forKey: "codey.sync.lastSyncedAt.\(userID.uuidString)") as? Date
    }

    func setLastSyncedAt(_ date: Date?, for userID: UUID) {
        defaults.set(date, forKey: "codey.sync.lastSyncedAt.\(userID.uuidString)")
    }

    private func key(_ userID: UUID) -> String { "codey.sync.pullCursor.\(userID.uuidString)" }
}
