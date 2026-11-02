import Foundation
import SwiftData

// MARK: - [Pattern: Facade] Facade (decks)
/// Deck and card writes (FR-10–15, FR-44): local save first, then queue the
/// sync operations. Part of the BackendFacade (§9.4).
extension BackendFacade {
    /// Edit → save (Fig. 7) only when the draft changed something, so an
    /// unchanged save neither bumps updatedAt nor queues a push.
    func saveDeck(_ draft: DeckDraft) throws -> FlashcardDeck {
        let result: DraftSaveResult
        do {
            result = try store.apply(draft, ownerId: userID)
        } catch {
            context.rollback()
            throw error
        }
        let deck = result.deck
        if result.deckChanged {
            deck.editAndSave(at: now())
            try queue.enqueue(.deck, id: deck.id, op: .upsert, ownerId: deck.ownerId)
            // Changed cards are the deck's own: read them off the relationship.
            let cards = deck.cards.keyed(by: \.id)
            for id in result.changedCardIDs {
                try queue.enqueue(.card, id: id, op: SyncOperationKind(deletedAt: cards[id]?.deletedAt), ownerId: deck.ownerId)
            }
            try queue.remove(.card, ids: result.hardDeletedCardIDs)
        } else if deck.syncState == .drafting {
            deck.save(at: now())
        }
        // The first saved user deck earns a badge (FR-35).
        try BadgeEvaluator.award(context: context)
        try persist()
        return deck
    }

    func deleteDeck(_ deck: FlashcardDeck) throws {
        if let reason = deck.deleteBlockedReason {
            throw DeckBackendError.deleteNotAllowed(reason)
        }
        try queue.remove(.card, ids: deck.cards.map(\.id))
        if deck.hasEverSynced {
            deck.delete(at: now())
            try queue.enqueue(.deck, id: deck.id, op: .delete, ownerId: deck.ownerId)
        } else {
            try queue.remove(.deck, ids: [deck.id])
            context.delete(deck)
        }
        try persist()
    }

    /// FR-13 outside the builder.
    func deleteCard(_ card: Flashcard) throws {
        guard let deck = card.deck, deck.canEdit else { throw DeckBackendError.notEditable }
        deck.edit()
        if deck.hasEverSynced {
            card.deletedAt = now()
            card.updatedAt = now()
            try queue.enqueue(.card, id: card.id, op: .delete, ownerId: deck.ownerId)
        } else {
            try queue.remove(.card, ids: [card.id])
            context.delete(card)
        }
        deck.save(at: now())
        try queue.enqueue(.deck, id: deck.id, op: .upsert, ownerId: deck.ownerId)
        try persist()
    }

    func setHidden(_ hidden: Bool, deck: FlashcardDeck) throws {
        guard deck.origin == .starter else { return }
        deck.isHidden = hidden
        try context.save()
    }
}
