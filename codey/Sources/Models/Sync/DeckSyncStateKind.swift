/// Persisted sync state of a deck (Fig. 7). Only this raw value is stored;
/// the behaviour lives in the DeckSyncState objects (Services/Sync).
enum DeckSyncStateKind: String, Codable, CaseIterable, Sendable {
    case drafting
    case locallyPersisted
    case syncing
    case synced
    case conflict
}
