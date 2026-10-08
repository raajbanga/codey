import Testing
@testable import codey

struct LevelCalculatorTests {

    @Test(arguments: [
        (xp: 0, level: 1, into: 0, next: 500, toGo: 500),
        (xp: 499, level: 1, into: 499, next: 500, toGo: 1),
        (xp: 500, level: 2, into: 0, next: 1000, toGo: 500),
        (xp: 999, level: 2, into: 499, next: 1000, toGo: 1),
        (xp: 1000, level: 3, into: 0, next: 1500, toGo: 500),
    ])
    func boundaries(xp: Int, level: Int, into: Int, next: Int, toGo: Int) {
        #expect(LevelCalculator.level(forXP: xp) == level)
        #expect(LevelCalculator.xpIntoLevel(xp) == into)
        #expect(LevelCalculator.xpForNextLevel(xp) == next)
        #expect(LevelCalculator.xpToNextLevel(xp) == toGo)
        #expect(LevelCalculator.progressFraction(xp) == Double(into) / 500)
    }

    @Test func negativeXPIsTreatedAsZero() {
        #expect(LevelCalculator.level(forXP: -10) == 1)
        #expect(LevelCalculator.progressFraction(-10) == 0)
    }
}
