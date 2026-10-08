import Testing
@testable import codey

struct XPPolicyTests {
    @Test func tierBases() {
        #expect(XPPolicy.base(.easy) == 10)
        #expect(XPPolicy.base(.medium) == 15)
        #expect(XPPolicy.base(.hard) == 20)
    }

    /// D5: base + min(5 × (streak − 1), 25), for every tier × streak 1…8.
    @Test(arguments: Difficulty.allCases)
    func streakTable(tier: Difficulty) {
        let bonuses = [0, 5, 10, 15, 20, 25, 25, 25]
        for (offset, bonus) in bonuses.enumerated() {
            let streak = offset + 1
            #expect(XPPolicy.xpForCorrectAnswer(tier: tier, streakAfterIncrement: streak) == XPPolicy.base(tier) + bonus)
        }
    }

    @Test func easySequenceMatchesTheDoc() {
        let xp = (1...7).map { XPPolicy.xpForCorrectAnswer(tier: .easy, streakAfterIncrement: $0) }
        #expect(xp == [10, 15, 20, 25, 30, 35, 35])
    }

    @Test func maxIsFortyFive() {
        #expect(XPPolicy.xpForCorrectAnswer(tier: .hard, streakAfterIncrement: 100) == 45)
    }

    @Test func zeroStreakHasNoBonus() {
        #expect(XPPolicy.streakBonus(0) == 0)
    }

    @Test func breakdownText() {
        #expect(XPPolicy.breakdown(tier: .medium, streakAfterIncrement: 3) == "Medium 15 + streak 10")
        #expect(XPPolicy.breakdown(tier: .easy, streakAfterIncrement: 1) == "Easy 10")
    }
}
