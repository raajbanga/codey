import Foundation
import SwiftData
import Testing
@testable import codey

/// FR-47 additive merge: add/add, edit/edit, delete/edit (both orders).
@MainActor
struct ConflictResolverTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func makeDeck() throws -> (FlashcardDeck, ModelContext) {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertDeck(context, prompts: ["Shared"])
        deck.updatedAt = at(0)
        deck.serverUpdatedAt = at(0)
        deck.cards[0].updatedAt = at(0)
        try context.save()
        return (deck, context)
    }

    private func remoteDeck(_ deck: FlashcardDeck, title: String? = nil, updatedAt: Date, deletedAt: Date? = nil) -> DeckPayload {
        DeckPayload(id: deck.id, title: title ?? deck.title, topicId: deck.topicId, createdAt: deck.createdAt,
                    updatedAt: updatedAt, deletedAt: deletedAt, serverUpdatedAt: at(500))
    }

    private func remoteCard(_ id: UUID, deck: FlashcardDeck, prompt: String, updatedAt: Date, deletedAt: Date? = nil) -> RemoteCard {
        RemoteCard(deckId: deck.id, card: FlashcardPayload(
            id: id, prompt: prompt, answer: "A", createdAt: at(0), updatedAt: updatedAt, deletedAt: deletedAt
        ))
    }

    private func merge(_ deck: FlashcardDeck, _ context: ModelContext, remote: DeckPayload, cards: [RemoteCard]) throws -> ConflictResolver.Outcome {
        try ConflictResolver(context: context).merge(deck, with: RemoteDeckSnapshot(deck: remote, cards: cards))
    }

    @Test func addAddKeepsTheUnionOfCards() throws {
        let (deck, context) = try makeDeck()
        let shared = deck.cards[0]
        let local = try FlashcardFactory().createCard(prompt: "Local only", answer: "A")
        context.insert(local)
        local.deck = deck
        let remoteOnly = UUID()

        let outcome = try merge(deck, context, remote: remoteDeck(deck, updatedAt: at(0)), cards: [
            remoteCard(shared.id, deck: deck, prompt: "Shared", updatedAt: at(0)),
            remoteCard(remoteOnly, deck: deck, prompt: "Remote only", updatedAt: at(10)),
        ])

        #expect(Set(deck.activeCards.map(\.prompt)) == ["Shared", "Local only", "Remote only"])
        #expect(outcome.cardsToPush == [local.id])
        #expect(outcome.cardsTakenFromRemote == [remoteOnly])
        #expect(deck.serverUpdatedAt == at(500))
    }

    @Test(arguments: [true, false])
    func editEditLaterUpdatedAtWins(remoteIsLater: Bool) throws {
        let (deck, context) = try makeDeck()
        let card = deck.cards[0]
        card.prompt = "Local edit"
        card.updatedAt = at(remoteIsLater ? 10 : 20)

        let outcome = try merge(deck, context, remote: remoteDeck(deck, updatedAt: at(0)), cards: [
            remoteCard(card.id, deck: deck, prompt: "Remote edit", updatedAt: at(remoteIsLater ? 20 : 10)),
        ])

        #expect(card.prompt == (remoteIsLater ? "Remote edit" : "Local edit"))
        #expect(outcome.cardsToPush == (remoteIsLater ? [] : [card.id]))
    }

    @Test func localDeleteAfterRemoteEditWins() throws {
        let (deck, context) = try makeDeck()
        let card = deck.cards[0]
        card.deletedAt = at(20)
        card.updatedAt = at(20)

        let outcome = try merge(deck, context, remote: remoteDeck(deck, updatedAt: at(0)), cards: [
            remoteCard(card.id, deck: deck, prompt: "Remote edit", updatedAt: at(10)),
        ])
        #expect(card.deletedAt == at(20))
        #expect(outcome.cardsToPush == [card.id])
    }

    @Test func remoteEditAfterLocalDeleteWins() throws {
        let (deck, context) = try makeDeck()
        let card = deck.cards[0]
        card.deletedAt = at(10)
        card.updatedAt = at(10)

        _ = try merge(deck, context, remote: remoteDeck(deck, updatedAt: at(0)), cards: [
            remoteCard(card.id, deck: deck, prompt: "Remote edit", updatedAt: at(20)),
        ])
        #expect(card.deletedAt == nil)
        #expect(card.prompt == "Remote edit")
    }

    @Test func remoteDeleteAfterLocalEditWins() throws {
        let (deck, context) = try makeDeck()
        let card = deck.cards[0]
        card.prompt = "Local edit"
        card.updatedAt = at(10)

        _ = try merge(deck, context, remote: remoteDeck(deck, updatedAt: at(0)), cards: [
            remoteCard(card.id, deck: deck, prompt: "Shared", updatedAt: at(0), deletedAt: at(20)),
        ])
        #expect(card.deletedAt == at(20))
    }

    @Test func localEditAfterRemoteDeleteWins() throws {
        let (deck, context) = try makeDeck()
        let card = deck.cards[0]
        card.prompt = "Local edit"
        card.updatedAt = at(20)

        let outcome = try merge(deck, context, remote: remoteDeck(deck, updatedAt: at(0)), cards: [
            remoteCard(card.id, deck: deck, prompt: "Shared", updatedAt: at(0), deletedAt: at(10)),
        ])
        #expect(card.deletedAt == nil)
        #expect(card.prompt == "Local edit")
        #expect(outcome.cardsToPush == [card.id])
    }

    @Test(arguments: [true, false])
    func deckTitleLaterUpdatedAtWins(remoteIsLater: Bool) throws {
        let (deck, context) = try makeDeck()
        deck.title = "Local title"
        deck.updatedAt = at(remoteIsLater ? 10 : 20)

        _ = try merge(deck, context, remote: remoteDeck(deck, title: "Remote title", updatedAt: at(remoteIsLater ? 20 : 10)), cards: [])
        #expect(deck.title == (remoteIsLater ? "Remote title" : "Local title"))
    }

    @Test func remoteDeckDeleteAfterLocalEditTombstonesEverything() throws {
        let (deck, context) = try makeDeck()
        deck.updatedAt = at(10)

        _ = try merge(deck, context, remote: remoteDeck(deck, updatedAt: at(0), deletedAt: at(20)), cards: [])
        #expect(deck.deletedAt == at(20))
        #expect(deck.cards.allSatisfy { $0.deletedAt != nil })
    }

    /// Mastery is local progress and survives a remote win.
    @Test func remoteWinKeepsLocalMastery() throws {
        let (deck, context) = try makeDeck()
        let card = deck.cards[0]
        card.updateMastery(rating: .easy)

        _ = try merge(deck, context, remote: remoteDeck(deck, updatedAt: at(0)), cards: [
            remoteCard(card.id, deck: deck, prompt: "Remote edit", updatedAt: at(20)),
        ])
        #expect(card.prompt == "Remote edit")
        #expect(card.masteryScore == 2)
    }
}
