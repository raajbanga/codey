import Foundation
import SwiftData

extension CodeySchemaV11 {
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

    /// Cards you study: not tombstoned and not hidden (§3b). Progress,
    /// mastery and tier gating count only these.
    var studyCards: LazyFilterSequence<[Flashcard]> {
        cards.lazy.filter { $0.deletedAt == nil && !$0.isHidden }
    }

    /// Cards that aren't tombstoned, in deck order (hidden ones included).
    var activeCards: [Flashcard] {
        cards.filter { $0.deletedAt == nil }.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Cards that aren't tombstoned, in no particular order: for counts,
    /// sums and lookups, where sorting (and an array) would be wasted work.
    var unorderedActiveCards: LazyFilterSequence<[Flashcard]> {
        cards.lazy.filter { $0.deletedAt == nil }
    }

    /// Doc: getCardCount().
    var cardCount: Int {
        unorderedActiveCards.count
    }

    /// Every study card mastered (and at least one): stops at the first
    /// card that isn't, so most decks read only a card or two.
    var isFullyMastered: Bool {
        var any = false
        for card in studyCards {
            guard card.isMastered else { return false }
            any = true
        }
        return any
    }

    /// Any card that isn't tombstoned: stops at the first, where
    /// `cardCount > 0` reads every card's attributes.
    var hasActiveCards: Bool {
        cards.contains { $0.deletedAt == nil }
    }

    /// Doc: calculateMasteryRate() — mastered / total active cards, 0 when empty.
    var masteryRate: Double {
        var total = 0, mastered = 0
        for card in studyCards {
            total += 1
            if card.isMastered { mastered += 1 }
        }
        return total == 0 ? 0 : Double(mastered) / Double(total)
    }

    /// Mastery points earned / points possible (5 per active card), 0 when
    /// empty (S19). Unlike masteryRate it moves with every Good or Easy, so
    /// a first pass through a deck shows progress instead of 0%.
    var progressRate: Double {
        var total = 0, points = 0
        for card in studyCards {
            total += 1
            points += card.masteryScore
        }
        return total == 0 ? 0 : Double(points) / Double(total * Flashcard.maxMastery)
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

extension CodeySchemaV2 {
    /// Frozen in V2 (stored properties only). The live model is V11's.
    @Model
    final class FlashcardDeck {
        @Attribute(.unique) var id: UUID
        var title: String
        var topicId: String
        var originRaw: String
        var starterKey: String?
        var isHidden: Bool = false
        var syncStateRaw: String
        var ownerId: UUID?
        var createdAt: Date
        var updatedAt: Date
        var lastSyncedAt: Date?
        var serverUpdatedAt: Date?
        var deletedAt: Date?

        @Relationship(deleteRule: .cascade, inverse: \Flashcard.deck)
        var cards: [Flashcard] = []

        init(id: UUID, title: String, topicId: String, originRaw: String, syncStateRaw: String, createdAt: Date) {
            self.id = id
            self.title = title
            self.topicId = topicId
            self.originRaw = originRaw
            self.syncStateRaw = syncStateRaw
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }
}
