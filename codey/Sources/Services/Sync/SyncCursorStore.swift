import Foundation

/// The sync cursors and push markers, per account, in UserDefaults.
struct SyncCursorStore {
    var defaults: UserDefaults = .standard

    enum Key: String {
        /// The pull cursor: the largest decks/flashcards server_updated_at seen.
        case pullCursor
        case lastSyncedAt
        /// FR-61: study progress has its own pull cursor and a push marker
        /// (local rows reviewed after it haven't been pushed yet).
        case progressCursor
        case progressPushedAt
        /// S43 history (quiz answers, days, badges) has its own push marker,
        /// so the first sync after the update sent the whole history once,
        /// not only what changed since the last progress push.
        case historyPushedAt
    }

    func date(_ key: Key, for userID: UUID) -> Date? {
        defaults.object(forKey: name(key, userID)) as? Date
    }

    func set(_ date: Date?, _ key: Key, for userID: UUID) {
        defaults.set(date, forKey: name(key, userID))
    }

    private func name(_ key: Key, _ userID: UUID) -> String {
        "codey.sync.\(key.rawValue).\(userID.uuidString)"
    }
}
