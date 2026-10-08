/// Persisted sync state of a deck (Fig. 7). Behaviour per state arrives with
/// the DeckSyncState objects in Stage 9; this is only the stored raw value.
enum DeckSyncStateKind: String, Codable, CaseIterable {
    case drafting
    case locallyPersisted
    case syncing
    case synced
    case conflict
}
