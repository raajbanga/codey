import Foundation
import SwiftData

extension CodeySchemaV2 {
    /// A deck of flashcards (FR-05). The id is generated on the client and is
    /// the same id remotely.
    @Model
    final class FlashcardDeck {
        @Attribute(.unique) var id: UUID
        /// 1–60 characters (ModelValidator.Limits.deckTitle).
        var title: String
        /// Must match a Topic.id.
        var topicId: String
        /// Raw DeckOrigin. Stored as a String so #Predicate can filter on it.
        var originRaw: String
        /// Stable id from starter-decks.json; nil for user decks.
        var starterKey: String?
        /// Starter decks only (FR-15).
        var isHidden: Bool = false
        /// Raw DeckSyncStateKind.
        var syncStateRaw: String
        /// nil = guest/local; set on sign-in.
        var ownerId: UUID?
        var createdAt: Date
        var updatedAt: Date
        var lastSyncedAt: Date?
        /// Remote server_updated_at at the last sync; the conflict-check cursor.
        var serverUpdatedAt: Date?
        /// Tombstone kept until the delete has synced.
        var deletedAt: Date?

        @Relationship(deleteRule: .cascade, inverse: \Flashcard.deck)
        var cards: [Flashcard] = []

        init(
            id: UUID = UUID(),
            title: String,
            topicId: String,
            origin: DeckOrigin,
            starterKey: String? = nil,
            syncState: DeckSyncStateKind = .drafting,
            ownerId: UUID? = nil,
            now: Date = .now
        ) {
            self.id = id
            self.title = title
            self.topicId = topicId
            self.originRaw = origin.rawValue
            self.starterKey = starterKey
            self.syncStateRaw = syncState.rawValue
            self.ownerId = ownerId
            self.createdAt = now
            self.updatedAt = now
        }
    }
}

extension FlashcardDeck {
    var origin: DeckOrigin {
        get { DeckOrigin(rawValue: originRaw) ?? .user }
        set { originRaw = newValue.rawValue }
    }

    var syncState: DeckSyncStateKind {
        get { DeckSyncStateKind(rawValue: syncStateRaw) ?? .locallyPersisted }
        set { syncStateRaw = newValue.rawValue }
    }

    /// Cards that aren't tombstoned, in deck order.
    var activeCards: [Flashcard] {
        cards.filter { $0.deletedAt == nil }.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Doc: getCardCount().
    var cardCount: Int {
        cards.reduce(0) { $1.deletedAt == nil ? $0 + 1 : $0 }
    }

    /// Doc: calculateMasteryRate() — mastered / total active cards, 0 when empty.
    var masteryRate: Double {
        let active = activeCards
        guard !active.isEmpty else { return 0 }
        return Double(active.filter(\.isMastered).count) / Double(active.count)
    }

    var isEditable: Bool { origin == .user }

    /// Whether this deck ever reached the server. Never-synced rows can be
    /// hard-deleted; synced ones need a tombstone until the delete syncs.
    var hasEverSynced: Bool { lastSyncedAt != nil }

    /// Doc: #markDirty() — records a local content change.
    func markDirty(at date: Date = .now) {
        updatedAt = date
    }
}
