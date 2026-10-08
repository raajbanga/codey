/// Level math (FR-31): every 500 XP is one level, starting at Level 1.
enum LevelCalculator {
    static let xpPerLevel = 500

    static func level(forXP xp: Int) -> Int {
        max(xp, 0) / xpPerLevel + 1
    }

    /// XP earned inside the current level (0..<500).
    static func xpIntoLevel(_ xp: Int) -> Int {
        max(xp, 0) % xpPerLevel
    }

    /// Total XP at which the next level starts.
    static func xpForNextLevel(_ xp: Int) -> Int {
        level(forXP: xp) * xpPerLevel
    }

    /// XP still needed to reach the next level (1...500).
    static func xpToNextLevel(_ xp: Int) -> Int {
        xpForNextLevel(xp) - max(xp, 0)
    }

    /// Progress through the current level, 0.0..<1.0.
    static func progressFraction(_ xp: Int) -> Double {
        Double(xpIntoLevel(xp)) / Double(xpPerLevel)
    }
}
