import Foundation
import SwiftData
import Testing
@testable import codey

struct TierGateTests {
    private func tallies(easy: (Int, Int), medium: (Int, Int), hard: (Int, Int) = (4, 0)) -> [Difficulty: TierTally] {
        [
            .easy: TierTally(total: easy.0, retired: easy.1),
            .medium: TierTally(total: medium.0, retired: medium.1),
            .hard: TierTally(total: hard.0, retired: hard.1),
        ]
    }

    @Test func newLearnerHasOnlyEasy() {
        #expect(TierGate.unlockedTiers(tallies: tallies(easy: (4, 0), medium: (4, 0)), level: 1) == [.easy])
    }

    /// ceil(0.7 × 4) = 3.
    @Test func mediumUnlocksAtCeilSeventyPercentOfEasy() {
        #expect(TierGate.unlockedTiers(tallies: tallies(easy: (4, 2), medium: (4, 0)), level: 1) == [.easy])
        #expect(TierGate.unlockedTiers(tallies: tallies(easy: (4, 3), medium: (4, 0)), level: 1) == [.easy, .medium])
    }

    @Test func hardNeedsMediumRetiredAndLevelThree() {
        let ready = tallies(easy: (4, 4), medium: (4, 3))
        #expect(TierGate.unlockedTiers(tallies: ready, level: 2) == [.easy, .medium])
        #expect(TierGate.unlockedTiers(tallies: ready, level: 3) == [.easy, .medium, .hard])
        #expect(TierGate.unlockedTiers(tallies: tallies(easy: (4, 4), medium: (4, 2)), level: 9) == [.easy, .medium])
    }

    @Test func hardNeedsMediumUnlockedEvenIfMediumIsEmpty() {
        #expect(TierGate.unlockedTiers(tallies: tallies(easy: (4, 0), medium: (0, 0)), level: 5) == [.easy])
        #expect(TierGate.unlockedTiers(tallies: tallies(easy: (4, 3), medium: (0, 0)), level: 5) == [.easy, .medium, .hard])
    }

    @Test func emptyTiersCountAsComplete() {
        #expect(TierGate.unlockedTiers(tallies: [:], level: 3) == [.easy, .medium, .hard])
    }

    @Test func thresholdsComeFromConfig() {
        let strict = GatingConfig(mediumUnlockFraction: 1, hardUnlockFraction: 1, hardMinimumLevel: 1)
        #expect(TierGate.unlockedTiers(tallies: tallies(easy: (4, 3), medium: (4, 0)), level: 1, config: strict) == [.easy])
        #expect(TierGate.unlockedTiers(tallies: tallies(easy: (4, 4), medium: (4, 4)), level: 1, config: strict) == [.easy, .medium, .hard])
    }

    @Test func lockReasons() {
        let tiers = TierGate.availability(tallies: tallies(easy: (4, 1), medium: (4, 0)), xp: 80, level: 1)
        #expect(tiers.map(\.isUnlocked) == [true, false, false])
        #expect(tiers[1].lockReason == "Master 2 more Easy cards")
        #expect(tiers[2].lockReason == "Unlock Medium first · Reach Level 3 · 920 XP to go")

        let later = TierGate.availability(tallies: tallies(easy: (4, 4), medium: (4, 1)), xp: 1200, level: 3)
        #expect(later[2].lockReason == "Master 2 more Medium cards")
    }

    @MainActor
    @Test func starterTalliesCountRetiredCardsAndUserDecksAreNeverLocked() throws {
        let context = try TestSupport.inMemoryContext()
        let starter = try TestSupport.insertTieredDeck(context, origin: .starter, tiers: [.easy, .easy, .medium])
        let easy = starter.activeCards[0]
        for _ in 0..<3 { easy.updateMastery(rating: .easy) }

        let tally = TierGate.tallies(for: starter)
        #expect(tally[.easy] == TierTally(total: 2, retired: 1))
        #expect(tally[.medium] == TierTally(total: 1, retired: 0))
        #expect(TierGate.unlockedTiers(for: starter, level: 1) == [.easy])

        let user = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [.easy, .hard])
        #expect(TierGate.unlockedTiers(for: user, level: 1) == Set(Difficulty.allCases))
    }
}

@MainActor
struct StudyPoolTests {
    @Test func starterPoolSkipsRetiredAndLockedTiers() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .starter, tiers: [.easy, .easy, .medium, .hard])
        for _ in 0..<3 { deck.activeCards[0].updateMastery(rating: .easy) }

        let pool = StudyPool.cards(in: deck, unlockedTiers: [.easy, .medium], tierFilter: nil)
        #expect(pool.map(\.sortIndex) == [1, 2])
    }

    @Test func tierFilterRestrictsToOneTier() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .starter, tiers: [.easy, .medium, .medium])
        let pool = StudyPool.cards(in: deck, unlockedTiers: [.easy, .medium], tierFilter: .medium)
        #expect(pool.map(\.sortIndex) == [1, 2])
    }

    @Test func userPoolIncludesMasteredCardsAndUntaggedCards() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil, .hard])
        for _ in 0..<3 { deck.activeCards[0].updateMastery(rating: .easy) }

        #expect(StudyPool.cards(in: deck, unlockedTiers: [], tierFilter: nil).count == 2)
        #expect(StudyPool.cards(in: deck, unlockedTiers: [], tierFilter: .hard).map(\.sortIndex) == [1])
        #expect(StudyPool.taggedTiers(in: deck) == [.hard])
    }

    @Test func tombstonedCardsAreNeverStudied() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil, nil])
        deck.activeCards[0].deletedAt = .now
        #expect(StudyPool.cards(in: deck, unlockedTiers: [], tierFilter: nil).count == 1)
    }
}
