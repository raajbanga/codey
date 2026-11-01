import Foundation
import SwiftData

/// What a draft save changed, so the facade knows what to queue.
struct DraftSaveResult {
    let deck: FlashcardDeck
    /// New or edited cards, plus cards tombstoned by the save.
    let changedCardIDs: [UUID]
    /// Never-synced cards removed outright (drop their queued upserts).
    let hardDeletedCardIDs: [UUID]
    let deckChanged: Bool
}

// MARK: - [Pattern: Facade] Subsystem (local store)
// MARK: - [Pattern: Factory] Client (builder saves)
/// Local deck storage (doc: SwiftDataService). Applies builder drafts
/// through FlashcardFactory.
@MainActor
struct SwiftDataService {
    let context: ModelContext
    var factory = FlashcardFactory()
    var now: () -> Date = Date.init

    /// Includes tombstoned decks (sync needs them).
    func fetch(id: UUID) throws -> FlashcardDeck? {
        try context.first(#Predicate<FlashcardDeck> { $0.id == id })
    }

    func fetchCard(id: UUID) throws -> Flashcard? {
        try context.first(#Predicate<Flashcard> { $0.id == id })
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
            context.insert(deck)
            deckChanged = true
        }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        deckChanged = deckChanged || deck.title != title || deck.topicId != draft.topicId
        deck.title = title
        deck.topicId = draft.topicId

        var changed: [UUID] = []
        var hardDeleted: [UUID] = []
        let existing = deck.cards.filter { $0.deletedAt == nil }.keyed(by: \.id)
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
