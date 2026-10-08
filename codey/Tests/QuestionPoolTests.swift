import Foundation
import Testing
@testable import codey

/// FR-19 / FR-27 / FR-29 quiz building.
struct QuestionPoolTests {
    private func candidates(easy: Int, medium: Int, hard: Int, retired: Set<String> = []) -> [PoolCandidate] {
        var result: [PoolCandidate] = []
        for (tier, count, tag) in [(Difficulty.easy, easy, "e"), (.medium, medium, "m"), (.hard, hard, "h")] {
            for n in 0..<count {
                let id = "\(tag)\(n)"
                result.append(PoolCandidate(id: id, difficulty: tier, isActive: !retired.contains(id)))
            }
        }
        return result
    }

    private func build(_ c: [PoolCandidate], _ unlocked: Set<Difficulty>, _ mode: QuizMode = .mixed, size: Int = 10, seed: UInt64 = 1) -> [String] {
        var rng = SeededGenerator(seed: seed)
        return QuestionPool.build(from: c, unlocked: unlocked, mode: mode, size: size, using: &rng)
    }

    private func count(_ ids: [String], _ tag: Character) -> Int { ids.filter { $0.first == tag }.count }

    @Test func easyOnlyWhenOnlyEasyIsUnlocked() {
        let ids = build(candidates(easy: 12, medium: 12, hard: 12), [.easy])
        #expect(ids.count == 10)
        #expect(count(ids, "e") == 10)
    }

    @Test func mixedTakesSeventyPercentFromTheHighestTier() {
        let ids = build(candidates(easy: 12, medium: 12, hard: 12), [.easy, .medium])
        #expect(count(ids, "m") == 7)
        #expect(count(ids, "e") == 3)
        #expect(count(ids, "h") == 0, "locked tiers never appear")
    }

    @Test func mixedWithAllTiersDrawsTheRestFromLowerTiers() {
        let ids = build(candidates(easy: 12, medium: 12, hard: 12), Set(Difficulty.allCases))
        #expect(count(ids, "h") == 7)
        #expect(count(ids, "e") + count(ids, "m") == 3)
        #expect(Set(ids).count == ids.count, "no duplicates")
    }

    @Test func backfillsWhenTheHighestTierIsShort() {
        let ids = build(candidates(easy: 12, medium: 2, hard: 0), [.easy, .medium])
        #expect(ids.count == 10)
        #expect(count(ids, "m") == 2)
        #expect(count(ids, "e") == 8)
    }

    @Test func backfillsFromTheHighestTierWhenLowerTiersAreShort() {
        let ids = build(candidates(easy: 1, medium: 12, hard: 0), [.easy, .medium])
        #expect(ids.count == 10)
        #expect(count(ids, "e") == 1)
        #expect(count(ids, "m") == 9)
    }

    @Test func smallPoolGivesFewerQuestions() {
        let ids = build(candidates(easy: 4, medium: 0, hard: 0), [.easy])
        #expect(ids.count == 4)
    }

    @Test func retiredQuestionsAreSkipped() {
        let ids = build(candidates(easy: 4, medium: 0, hard: 0, retired: ["e0", "e1"]), [.easy])
        #expect(Set(ids) == ["e2", "e3"])
    }

    @Test func restrictedModeUsesOneTier() {
        let ids = build(candidates(easy: 12, medium: 12, hard: 12), [.easy, .medium], .tier(.easy))
        #expect(ids.count == 10)
        #expect(count(ids, "e") == 10)
    }

    @Test func restrictedModeOnALockedTierIsEmpty() {
        #expect(build(candidates(easy: 12, medium: 12, hard: 12), [.easy], .tier(.hard)).isEmpty)
    }

    @Test func reviewModeUsesOnlyRetiredQuestions() {
        let ids = build(candidates(easy: 4, medium: 0, hard: 0, retired: ["e0", "e3"]), [.easy], .review)
        #expect(Set(ids) == ["e0", "e3"])
    }

    @Test func deterministicForASeed() {
        let c = candidates(easy: 12, medium: 12, hard: 12)
        let all = Set(Difficulty.allCases)
        #expect(build(c, all, seed: 42) == build(c, all, seed: 42))
        #expect(build(c, all, seed: 42) != build(c, all, seed: 43))
    }

    @Test func activeIDsFilterByUnlockAndRetirement() {
        let c = candidates(easy: 2, medium: 2, hard: 0, retired: ["e0"])
        #expect(QuestionPool.activeIDs(c, unlocked: [.easy]) == ["e1"])
    }
}
