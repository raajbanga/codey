import Foundation

/// How a quiz picks its questions (FR-19, FR-27, FR-29).
enum QuizMode: Hashable {
    /// 70% from the highest unlocked tier, the rest from lower tiers.
    case mixed
    /// FR-29 restricted mode: every question from one unlocked tier.
    case tier(Difficulty)
    /// Retired questions, practice only: no XP, no progress (pool exhausted).
    case review
}

/// One candidate question, reduced to what the builder needs.
struct PoolCandidate: Equatable {
    let id: String
    let difficulty: Difficulty
    /// Not retired (or returned for review).
    let isActive: Bool
}

/// Pure quiz builder. Deterministic for a given generator.
enum QuestionPool {
    /// Active questions in unlocked tiers (what a quiz can draw from).
    static func activeIDs(_ candidates: [PoolCandidate], unlocked: Set<Difficulty>) -> [String] {
        candidates.filter { $0.isActive && unlocked.contains($0.difficulty) }.map(\.id)
    }

    /// Picks up to `size` question ids.
    ///
    /// - mixed: take ceil(highestTierShare × size) from the highest unlocked
    ///   tier and the rest from lower unlocked tiers; if either side is
    ///   short, backfill from any active unlocked question. Only Easy
    ///   unlocked → all Easy.
    /// - tier(t): only active questions of t (t must be unlocked).
    /// - review: only retired questions, any unlocked tier.
    /// The result is shuffled.
    static func build<G: RandomNumberGenerator>(
        from candidates: [PoolCandidate],
        unlocked: Set<Difficulty>,
        mode: QuizMode,
        size: Int,
        config: GatingConfig = .standard,
        using generator: inout G
    ) -> [String] {
        let open = candidates.filter { unlocked.contains($0.difficulty) }
        switch mode {
        case .review:
            return Array(open.filter { !$0.isActive }.map(\.id).shuffled(using: &generator).prefix(size))
        case .tier(let tier):
            guard unlocked.contains(tier) else { return [] }
            return Array(open.filter { $0.isActive && $0.difficulty == tier }.map(\.id).shuffled(using: &generator).prefix(size))
        case .mixed:
            let active = open.filter(\.isActive)
            guard let highest = Difficulty.allCases.last(where: unlocked.contains) else { return [] }

            let top = active.filter { $0.difficulty == highest }.map(\.id).shuffled(using: &generator)
            let lower = active.filter { $0.difficulty != highest }.map(\.id).shuffled(using: &generator)
            let topTarget = Int((config.highestTierShare * Double(size)).rounded(.up))

            var picked = Array(top.prefix(topTarget))
            picked += lower.prefix(size - picked.count)
            if picked.count < size {
                // Backfill from whatever is left in any unlocked tier.
                let chosen = Set(picked)
                picked += (top + lower).filter { !chosen.contains($0) }.prefix(size - picked.count)
            }
            return picked.shuffled(using: &generator)
        }
    }
}
