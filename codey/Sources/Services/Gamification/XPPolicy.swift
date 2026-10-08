/// XP per correct quiz answer (FR-30 as amended by D5): tier base plus a
/// streak bonus capped at 25, so at most 45 XP per answer. Flashcard study
/// awards no XP (O2).
enum XPPolicy {
    static let streakBonusStep = 5
    static let streakBonusCap = 25

    static func base(_ tier: Difficulty) -> Int {
        switch tier {
        case .easy: 10
        case .medium: 15
        case .hard: 20
        }
    }

    /// min(5 × (streak − 1), 25), for a streak ≥ 1 (0 below that).
    static func streakBonus(_ streak: Int) -> Int {
        min(streakBonusStep * max(streak - 1, 0), streakBonusCap)
    }

    static func xpForCorrectAnswer(tier: Difficulty, streakAfterIncrement streak: Int) -> Int {
        base(tier) + streakBonus(streak)
    }

    /// "Medium 15 + streak 10" (or just "Medium 15").
    static func breakdown(tier: Difficulty, streakAfterIncrement streak: Int) -> String {
        let bonus = streakBonus(streak)
        let head = "\(tier.style.label) \(base(tier))"
        return bonus > 0 ? "\(head) + streak \(bonus)" : head
    }
}
