import Testing
@testable import codey

struct XPPolicyTests {
    /// D5: base + min(5 × (streak − 1), 25).
    @Test func easySequenceMatchesTheDoc() {
        let xp = (1...7).map { XPPolicy.xpForCorrectAnswer(tier: .easy, streakAfterIncrement: $0) }
        #expect(xp == [10, 15, 20, 25, 30, 35, 35])
    }

    @Test func tierBasesAndMaxOfFortyFive() {
        #expect(XPPolicy.xpForCorrectAnswer(tier: .medium, streakAfterIncrement: 1) == 15)
        #expect(XPPolicy.xpForCorrectAnswer(tier: .hard, streakAfterIncrement: 1) == 20)
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
