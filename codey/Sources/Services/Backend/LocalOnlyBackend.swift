import Foundation
import SwiftData
import os

/// SwiftData-only DeckBackend for guests and until sync lands (Stage 9).
@MainActor
struct LocalOnlyBackend: DeckBackend {
    let context: ModelContext
    var factory = FlashcardFactory()
    var now: () -> Date = Date.init

    func saveDeck(_ draft: DeckDraft) throws -> FlashcardDeck {
        let timestamp = now()
        let deck: FlashcardDeck
        if let id = draft.deckID {
            guard let existing = try fetchDeck(id: id) else { throw DeckBackendError.deckNotFound }
            guard existing.isEditable else { throw DeckBackendError.notEditable }
            deck = existing
        } else {
            deck = FlashcardDeck(title: draft.title, topicId: draft.topicId, origin: .user, now: timestamp)
            context.insert(deck)
        }

        do {
            try apply(draft, to: deck, at: timestamp)
        } catch FactoryError.invalid(let errors) {
            context.rollback()
            throw DeckBackendError.invalid(errors)
        }

        deck.syncState = .locallyPersisted
        do {
            try context.save()
        } catch {
            context.rollback()
            Logger.persistence.error("Saving deck failed: \(String(describing: error))")
            throw error
        }
        return deck
    }

    func deleteDeck(_ deck: FlashcardDeck) throws {
        if let reason = deck.deleteBlockedReason {
            throw DeckBackendError.deleteNotAllowed(reason)
        }
        if deck.hasEverSynced {
            // Tombstone until the delete reaches the server (Stage 9).
            let timestamp = now()
            deck.deletedAt = timestamp
            deck.markDirty(at: timestamp)
            for card in deck.cards where card.deletedAt == nil {
                card.deletedAt = timestamp
            }
        } else {
            context.delete(deck)
        }
        try context.save()
    }

    func setHidden(_ hidden: Bool, deck: FlashcardDeck) throws {
        guard deck.origin == .starter else { return }
        deck.isHidden = hidden
        try context.save()
    }

    private func apply(_ draft: DeckDraft, to deck: FlashcardDeck, at timestamp: Date) throws {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        var changed = deck.title != title || deck.topicId != draft.topicId
        deck.title = title
        deck.topicId = draft.topicId

        let existing = Dictionary(
            deck.cards.filter { $0.deletedAt == nil }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for (index, cardDraft) in draft.cards.enumerated() {
            if let card = existing[cardDraft.id] {
                changed = try factory.updateCard(
                    card,
                    prompt: cardDraft.prompt,
                    answer: cardDraft.answer,
                    code: cardDraft.codeSnippet,
                    difficulty: cardDraft.difficulty,
                    sortIndex: index
                ) || changed
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
                changed = true
            }
        }

        // FR-13: cards removed in the builder.
        let kept = Set(draft.cards.map(\.id))
        for (id, card) in existing where !kept.contains(id) {
            if deck.hasEverSynced {
                card.deletedAt = timestamp
                card.updatedAt = timestamp
            } else {
                context.delete(card)
            }
            changed = true
        }

        if changed { deck.markDirty(at: timestamp) }
    }

    private func fetchDeck(id: UUID) throws -> FlashcardDeck? {
        var descriptor = FetchDescriptor<FlashcardDeck>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
