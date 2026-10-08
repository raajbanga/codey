import Foundation
import SwiftData
import Testing
@testable import codey

@MainActor
struct StudySessionViewModelTests {
    private let day = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeVM(
        _ deck: FlashcardDeck,
        _ context: ModelContext,
        start: StudySessionViewModel.Start = .fresh(tierFilter: nil)
    ) -> StudySessionViewModel {
        StudySessionViewModel(deck: deck, start: start, context: context, now: { [day] in day })
    }

    private func revealAndRate(_ vm: StudySessionViewModel, _ rating: CardRating) {
        vm.toggleReveal()
        vm.rate(rating)
    }

    private func snapshots(_ context: ModelContext) throws -> [StudyProgressSnapshot] {
        try context.fetch(FetchDescriptor<StudyProgressSnapshot>())
    }

    @Test func userDeckStudiesEveryCardInOrder() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil, .hard, nil])
        let vm = makeVM(deck, context)

        #expect(vm.queue.total == 3)
        #expect(vm.currentCard?.id == deck.activeCards[0].id)
        #expect(!vm.isFinished)
    }

    @Test func ratingNeedsTheAnswerRevealedFirst() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil])
        let vm = makeVM(deck, context)

        #expect(vm.rate(.good) == nil)
        #expect(deck.activeCards[0].masteryScore == 0)

        vm.toggleReveal()
        vm.toggleReveal() // peeked, flipped back: rating still allowed
        #expect(!vm.isRevealed && vm.hasRevealedCurrent)
        #expect(vm.rate(.good) != nil)
        #expect(deck.activeCards[0].masteryScore == 1)
    }

    @Test func ratingUpdatesMasteryAndPersists() throws {
        let url = try TestSupport.temporaryStoreURL()
        let deckID: UUID
        do {
            let context = try TestSupport.context(storeURL: url)
            let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil, nil])
            deckID = deck.id
            let vm = makeVM(deck, context)
            revealAndRate(vm, .easy)
        }

        let context = try TestSupport.context(storeURL: url)
        let deck = try #require(try context.fetch(FetchDescriptor<FlashcardDeck>(predicate: #Predicate { $0.id == deckID })).first)
        #expect(deck.activeCards[0].masteryScore == 2)
        #expect(deck.activeCards[0].lastReviewedAt == day)
        let snapshot = try #require(try StudyProgressSnapshot.fetch(deckId: deckID, context: context))
        #expect(snapshot.position == 1)
        #expect(snapshot.reviewedCount == 1)
    }

    @Test func againRequeuesOnceThenFinishes() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil, nil])
        let first = deck.activeCards[0].id
        let vm = makeVM(deck, context)

        revealAndRate(vm, .again)
        revealAndRate(vm, .good)
        #expect(vm.currentCard?.id == first)
        #expect(vm.queue.total == 3)
        revealAndRate(vm, .again)

        let summary = try #require(vm.summary)
        #expect(summary.reviewed == 3)
        #expect(try snapshots(context).isEmpty, "finishing deletes the snapshot")
    }

    @Test func everyRatingCountsTowardDailyActivity() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil, nil])
        let vm = makeVM(deck, context)
        revealAndRate(vm, .again)
        revealAndRate(vm, .good)

        let activity = try DailyActivity.forDay(day, context: context)
        #expect(activity.cardsRated == 2)
        #expect(activity.day == DailyActivity.dayKey(for: day))
        #expect(try context.fetchCount(FetchDescriptor<DailyActivity>()) == 1)
    }

    @Test func summaryCountsNewlyMasteredAndMasteryDelta() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil, nil])
        deck.activeCards[0].updateMastery(rating: .easy)
        deck.activeCards[0].updateMastery(rating: .easy) // 4
        let vm = makeVM(deck, context)

        let outcome = try #require({ vm.toggleReveal(); return vm.rate(.good) }())
        #expect(outcome.becameMastered)
        #expect(!outcome.retired, "user cards never retire")
        revealAndRate(vm, .hard)

        let summary = try #require(vm.summary)
        #expect(summary.newlyMastered == 1)
        #expect(summary.startMasteryRate == 0)
        #expect(summary.endMasteryRate == 0.5)
        #expect(summary.unlockedTiers.isEmpty)
    }

    @Test func resumeContinuesWhereTheSessionLeftOff() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil, nil, nil])
        let vm = makeVM(deck, context)
        revealAndRate(vm, .again)
        revealAndRate(vm, .good)

        let resumed = makeVM(deck, context, start: .resume)
        #expect(resumed.queue.position == 2)
        #expect(resumed.queue.total == 4)
        #expect(resumed.currentCard?.id == deck.activeCards[2].id)
        #expect(!resumed.hasRevealedCurrent)

        revealAndRate(resumed, .good)
        revealAndRate(resumed, .good)
        #expect(resumed.summary?.reviewed == 4, "stats carry over from before the resume")
    }

    @Test func resumeSkipsCardsDeletedSinceTheSnapshot() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil, nil, nil])
        let vm = makeVM(deck, context)
        revealAndRate(vm, .good)
        deck.activeCards[1].deletedAt = .now

        let resumed = makeVM(deck, context, start: .resume)
        #expect(resumed.queue.total == 2)
        #expect(resumed.currentCard?.id == deck.activeCards.last?.id)
    }

    @Test func resumeWithoutSnapshotStartsFresh() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil, nil])
        let vm = makeVM(deck, context, start: .resume)
        #expect(vm.queue.position == 0)
        #expect(vm.queue.total == 2)
    }

    @Test func freshSessionReplacesTheSnapshot() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil, nil])
        revealAndRate(makeVM(deck, context), .good)
        #expect(try snapshots(context).count == 1)

        let fresh = makeVM(deck, context)
        #expect(fresh.queue.position == 0)
        #expect(try snapshots(context).isEmpty, "the old session is gone until the first rating")
    }

    @Test func tierFilterIsKeptAcrossResume() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [.easy, .hard, .hard])
        let vm = makeVM(deck, context, start: .fresh(tierFilter: .hard))
        #expect(vm.queue.total == 2)
        revealAndRate(vm, .good)

        let resumed = makeVM(deck, context, start: .resume)
        #expect(resumed.tierFilter == .hard)
        #expect(resumed.queue.total == 2)
    }

    // MARK: Starter decks (D9)

    @Test func starterSessionOnlyIncludesUnlockedUnretiredCards() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .starter, tiers: [.easy, .easy, .medium, .hard])
        for _ in 0..<3 { deck.activeCards[0].updateMastery(rating: .easy) }

        let vm = makeVM(deck, context)
        #expect(vm.queue.cardIDs == [deck.activeCards[1].id])
    }

    @Test func masteringStarterCardsRetiresThemAndUnlocksMedium() throws {
        let context = try TestSupport.inMemoryContext()
        // 3 Easy → Medium needs ceil(2.1) = 3 retired.
        let deck = try TestSupport.insertTieredDeck(context, origin: .starter, tiers: [.easy, .easy, .easy, .medium])
        let cards = deck.activeCards
        for _ in 0..<3 { cards[0].updateMastery(rating: .easy) }
        for _ in 0..<3 { cards[1].updateMastery(rating: .easy) }
        cards[2].updateMastery(rating: .easy)
        cards[2].updateMastery(rating: .easy) // 4

        let vm = makeVM(deck, context)
        #expect(vm.unlockedTiers == [.easy])
        #expect(vm.queue.cardIDs == [cards[2].id])

        vm.toggleReveal()
        let outcome = try #require(vm.rate(.good))
        #expect(outcome.becameMastered && outcome.retired)
        #expect(cards[2].retiredAt == day)

        let summary = try #require(vm.summary)
        #expect(summary.unlockedTiers == [.medium])

        // Next session: the retired cards are gone, Medium is in.
        let next = makeVM(deck, context)
        #expect(next.queue.cardIDs == [cards[3].id])
    }

    @Test func hardStaysLockedBelowLevelThree() throws {
        let context = try TestSupport.inMemoryContext()
        context.insert(UserProfile(username: "x", totalXP: 999)) // level 2
        let deck = try TestSupport.insertTieredDeck(context, origin: .starter, tiers: [.easy, .medium, .hard])
        for card in deck.activeCards.prefix(2) {
            for _ in 0..<3 { card.updateMastery(rating: .easy) }
        }
        #expect(makeVM(deck, context).wasEmpty)

        try #require(try context.fetch(FetchDescriptor<UserProfile>()).first).totalXP = 1000 // level 3
        let vm = makeVM(deck, context)
        #expect(vm.queue.cardIDs == [deck.activeCards[2].id])
    }

    @Test func fullyRetiredStarterDeckIsAnEmptySession() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .starter, tiers: [.easy])
        for _ in 0..<3 { deck.activeCards[0].updateMastery(rating: .easy) }

        let vm = makeVM(deck, context)
        #expect(vm.isFinished)
        #expect(vm.wasEmpty)
        #expect(vm.currentCard == nil)
        #expect(try snapshots(context).isEmpty)
    }

    @Test func restartStartsANewSessionWithTheSameFilter() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [.easy, .hard])
        let vm = makeVM(deck, context, start: .fresh(tierFilter: .easy))
        revealAndRate(vm, .good)
        #expect(vm.isFinished)

        vm.restart()
        #expect(!vm.isFinished)
        #expect(vm.tierFilter == .easy)
        #expect(vm.queue.total == 1)
        #expect(vm.lastOutcome == nil)
    }

    @Test func dayKeyUsesTheGivenCalendarsTimeZone() {
        let threeAM = Date(timeIntervalSince1970: 3 * 3600) // 1970-01-01 03:00 UTC
        let gregorian = Calendar(identifier: .gregorian)
        #expect(DailyActivity.dayKey(for: threeAM, calendar: gregorian.withTimeZone("UTC")) == "1970-01-01")
        #expect(DailyActivity.dayKey(for: threeAM, calendar: gregorian.withTimeZone("America/Chicago")) == "1969-12-31")
    }
}

private extension Calendar {
    func withTimeZone(_ identifier: String) -> Calendar {
        var copy = self
        copy.timeZone = TimeZone(identifier: identifier)!
        return copy
    }
}
