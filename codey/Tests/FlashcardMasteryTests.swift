import Foundation
import SwiftData
import Testing
@testable import codey

struct CardRatingTests {
    @Test(arguments: [
        (CardRating.again, 3, 0), (.again, 0, 0),
        (.hard, 3, 3), (.hard, 0, 0),
        (.good, 3, 4), (.good, 5, 5),
        (.easy, 3, 5), (.easy, 4, 5), (.easy, 5, 5), (.easy, 0, 2),
    ])
    func ratingRule(rating: CardRating, from: Int, to: Int) {
        #expect(rating.applied(to: from) == to)
    }
}

@MainActor
struct FlashcardMasteryTests {

    private func card(in origin: DeckOrigin) throws -> (Flashcard, ModelContext) {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertDeck(context, origin: origin, prompts: ["p"])
        return (try #require(deck.activeCards.first), context)
    }

    @Test func allRatingsUpdateScoreAndReviewDate() throws {
        let (card, _) = try card(in: .user)
        let t = Date(timeIntervalSince1970: 5_000)

        card.updateMastery(rating: .good, at: t)
        #expect(card.masteryScore == 1)
        #expect(card.lastReviewedAt == t)
        card.updateMastery(rating: .easy)
        #expect(card.masteryScore == 3)
        card.updateMastery(rating: .hard)
        #expect(card.masteryScore == 3)
        card.updateMastery(rating: .again)
        #expect(card.masteryScore == 0)
    }

    @Test func masteryClampsAtFive() throws {
        let (card, _) = try card(in: .user)
        for _ in 0..<5 { card.updateMastery(rating: .easy) }
        #expect(card.masteryScore == 5)
        #expect(card.isMastered)
    }

    @Test func masteryDoesNotBumpContentTimestamp() throws {
        let (card, _) = try card(in: .user)
        let before = card.updatedAt
        card.updateMastery(rating: .easy, at: before.addingTimeInterval(100))
        #expect(card.updatedAt == before)
    }

    @Test func starterCardRetiresAtFiveAndUnretiresBelow() throws {
        let (card, _) = try card(in: .starter)
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)

        card.updateMastery(rating: .easy, at: t1)
        card.updateMastery(rating: .easy, at: t1)
        #expect(card.retiredAt == nil)
        card.updateMastery(rating: .good, at: t1)
        #expect(card.retiredAt == t1)

        card.updateMastery(rating: .good, at: t2)
        #expect(card.retiredAt == t1, "staying at 5 keeps the original retire date")

        card.updateMastery(rating: .again, at: t2)
        #expect(card.retiredAt == nil)
    }

    @Test func userCardsNeverRetire() throws {
        let (card, _) = try card(in: .user)
        for _ in 0..<3 { card.updateMastery(rating: .easy) }
        #expect(card.isMastered)
        #expect(card.retiredAt == nil)
    }

    @Test func resetMasteryClearsProgress() throws {
        let (card, _) = try card(in: .starter)
        for _ in 0..<3 { card.updateMastery(rating: .easy) }
        card.resetMastery()
        #expect(card.masteryScore == 0)
        #expect(card.retiredAt == nil)
        #expect(card.lastReviewedAt == nil)
    }
}

@MainActor
struct FlashcardDeckTests {

    @Test func activeCardsSkipTombstonesAndSortByIndex() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertDeck(context, prompts: ["a", "b", "c"])
        let cards = deck.activeCards
        cards[1].deletedAt = .now
        cards[0].sortIndex = 10

        #expect(deck.activeCards.map(\.prompt) == ["c", "a"])
        #expect(deck.cardCount == 2)
        #expect(deck.cards.count == 3)
    }

    @Test func masteryRateIsMasteredOverActive() throws {
        let context = try TestSupport.inMemoryContext()
        let empty = FlashcardDeck(title: "Empty", topicId: "t", origin: .user)
        context.insert(empty)
        #expect(empty.masteryRate == 0)

        let deck = try TestSupport.insertDeck(context, prompts: ["a", "b", "c", "d"])
        for _ in 0..<3 { deck.activeCards[0].updateMastery(rating: .easy) }
        #expect(deck.masteryRate == 0.25)
    }

    @Test func originAndSyncStateRoundTripThroughRawValues() {
        let deck = FlashcardDeck(title: "d", topicId: "t", origin: .starter, syncState: .synced)
        #expect(deck.originRaw == "starter")
        #expect(deck.syncState == .synced)
        #expect(!deck.isEditable)

        deck.origin = .user
        deck.syncState = .conflict
        #expect(deck.isEditable)
        #expect(deck.syncStateRaw == "conflict")
    }

    @Test func newDeckDefaults() {
        let now = Date(timeIntervalSince1970: 42)
        let deck = FlashcardDeck(title: "d", topicId: "t", origin: .user, now: now)
        #expect(deck.syncState == .drafting)
        #expect(deck.createdAt == now && deck.updatedAt == now)
        #expect(!deck.isHidden)
        #expect(deck.ownerId == nil && deck.deletedAt == nil && deck.lastSyncedAt == nil)
    }

    @Test func markDirtyBumpsUpdatedAt() {
        let deck = FlashcardDeck(title: "d", topicId: "t", origin: .user, now: Date(timeIntervalSince1970: 0))
        let later = Date(timeIntervalSince1970: 99)
        deck.markDirty(at: later)
        #expect(deck.updatedAt == later)
    }

    @Test func deletingDeckCascadesToCards() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertDeck(context, prompts: ["a", "b"])
        try context.save()

        context.delete(deck)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Flashcard>()) == 0)
    }

    @Test func languageMetadata() {
        #expect(CodeLanguage.cpp.displayName == "C++")
        #expect(CodeLanguage.cpp.fenceTag == "cpp")
        #expect(CodeLanguage.allCases.map(\.rawValue) == ["swift", "python", "java", "cpp"])
    }
}
