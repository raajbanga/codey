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

    /// BUG-06: the account whose study progress is on the device (the last
    /// one signed in). Another account's sign-in clears that progress first.
    var progressOwner: UUID? {
        get { defaults.string(forKey: Self.progressOwnerKey).flatMap(UUID.init(uuidString:)) }
        nonmutating set { defaults.set(newValue?.uuidString, forKey: Self.progressOwnerKey) }
    }

    private static let progressOwnerKey = "codey.sync.progressOwner"

    /// The account that synced on this device most recently (lastSyncedAt is
    /// kept at sign-out): the progress owner on installs from before
    /// progressOwner existed.
    var lastSyncedAccount: UUID? {
        let prefix = "codey.sync.\(Key.lastSyncedAt.rawValue)."
        return defaults.dictionaryRepresentation()
            .compactMap { key, value -> (UUID, Date)? in
                guard key.hasPrefix(prefix), let date = value as? Date,
                      let id = UUID(uuidString: String(key.dropFirst(prefix.count))) else { return nil }
                return (id, date)
            }
            .max { $0.1 < $1.1 }?.0
    }

    private func name(_ key: Key, _ userID: UUID) -> String {
        "codey.sync.\(key.rawValue).\(userID.uuidString)"
    }
}
