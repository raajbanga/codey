import Foundation
import SwiftData

/// Local deck storage (doc: SwiftDataService). Doc API: insert, fetchDecks,
/// delete, fetch(id:).
@MainActor
protocol LocalDeckStore {
    func insert(_ deck: FlashcardDeck)
    func fetchDecks() throws -> [FlashcardDeck]
    func fetch(id: UUID) throws -> FlashcardDeck?
    func delete(_ deck: FlashcardDeck)
}

/// What a draft save changed, so the facade knows what to queue.
struct DraftSaveResult {
    let deck: FlashcardDeck
    /// New or edited cards, plus cards tombstoned by the save.
    let changedCardIDs: [UUID]
    /// Never-synced cards removed outright (drop their queued upserts).
    let hardDeletedCardIDs: [UUID]
    let deckChanged: Bool
}

/// SwiftData implementation. Applies builder drafts through FlashcardFactory.
@MainActor
struct SwiftDataService: LocalDeckStore {
    let context: ModelContext
    var factory = FlashcardFactory()
    var now: () -> Date = Date.init

    func insert(_ deck: FlashcardDeck) {
        context.insert(deck)
    }

    /// Live (non-tombstoned) decks, newest first.
    func fetchDecks() throws -> [FlashcardDeck] {
        try context.fetch(FetchDescriptor<FlashcardDeck>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        ))
    }

    /// Includes tombstoned decks (sync needs them).
    func fetch(id: UUID) throws -> FlashcardDeck? {
        var descriptor = FetchDescriptor<FlashcardDeck>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchCard(id: UUID) throws -> Flashcard? {
        var descriptor = FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func delete(_ deck: FlashcardDeck) {
        context.delete(deck)
    }

    /// User decks in a sync state, for the engine.
    func userDecks(in state: DeckSyncStateKind) throws -> [FlashcardDeck] {
        let user = DeckOrigin.user.rawValue
        let raw = state.rawValue
        return try context.fetch(FetchDescriptor<FlashcardDeck>(
            predicate: #Predicate { $0.originRaw == user && $0.syncStateRaw == raw }
        ))
    }

    /// Writes a builder draft into a new or existing deck (no save, no state
    /// change). Throws DeckBackendError.
    func apply(_ draft: DeckDraft, ownerId: UUID?) throws -> DraftSaveResult {
        let timestamp = now()
        let deck: FlashcardDeck
        var deckChanged = false
        if let id = draft.deckID {
            guard let existing = try fetch(id: id), existing.deletedAt == nil else { throw DeckBackendError.deckNotFound }
            guard existing.isEditable else { throw DeckBackendError.notEditable }
            deck = existing
        } else {
            deck = FlashcardDeck(title: draft.title, topicId: draft.topicId, origin: .user, ownerId: ownerId, now: timestamp)
            insert(deck)
            deckChanged = true
        }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        deckChanged = deckChanged || deck.title != title || deck.topicId != draft.topicId
        deck.title = title
        deck.topicId = draft.topicId

        var changed: [UUID] = []
        var hardDeleted: [UUID] = []
        let existing = Dictionary(
            deck.cards.filter { $0.deletedAt == nil }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        do {
            for (index, cardDraft) in draft.cards.enumerated() {
                if let card = existing[cardDraft.id] {
                    let edited = try factory.updateCard(
                        card,
                        prompt: cardDraft.prompt,
                        answer: cardDraft.answer,
                        code: cardDraft.codeSnippet,
                        difficulty: cardDraft.difficulty,
                        sortIndex: index
                    )
                    if edited { changed.append(card.id) }
                } else {
                    let card = try factory.createCard(
                        id: cardDraft.id,
                        prompt: cardDraft.prompt,
                        answer: cardDraft.answer,
                        code: cardDraft.codeSnippet,
                        difficulty: cardDraft.difficulty,
                        sortIndex: index
                    )
                    context.insert(card)
                    card.deck = deck
                    changed.append(card.id)
                }
            }
        } catch FactoryError.invalid(let errors) {
            throw DeckBackendError.invalid(errors)
        }

        // FR-13: cards removed in the builder.
        let kept = Set(draft.cards.map(\.id))
        for (id, card) in existing where !kept.contains(id) {
            if deck.hasEverSynced {
                card.deletedAt = timestamp
                card.updatedAt = timestamp
                changed.append(id)
            } else {
                context.delete(card)
                hardDeleted.append(id)
            }
        }

        let anyChange = deckChanged || !changed.isEmpty || !hardDeleted.isEmpty
        if anyChange { deck.markDirty(at: timestamp) }
        return DraftSaveResult(deck: deck, changedCardIDs: changed, hardDeletedCardIDs: hardDeleted, deckChanged: anyChange)
    }
}
