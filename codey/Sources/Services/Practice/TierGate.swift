import Foundation

/// How many items of one tier exist and how many are retired.
struct TierTally: Equatable {
    var total = 0
    var retired = 0
}

/// Which difficulty tiers are open (FR-25/26/29).
///
/// Stage 5 uses it for STARTER decks, where "retired" = mastery 5 (D9). The
/// quiz bank (Stage 6) reuses the same rules with its own tallies and adds
/// sticky unlocks (TopicProgress).
enum TierGate {
    /// - Easy is always open.
    /// - Medium: retired(Easy) ≥ ceil(fraction × total(Easy)).
    /// - Hard: Medium is open, retired(Medium) ≥ ceil(fraction × total(Medium)),
    ///   and level ≥ hardMinimumLevel.
    /// An empty tier counts as complete.
    static func unlockedTiers(
        tallies: [Difficulty: TierTally],
        level: Int,
        config: GatingConfig = .standard
    ) -> Set<Difficulty> {
        Set(availability(tallies: tallies, xp: nil, level: level, config: config).filter(\.isUnlocked).map(\.difficulty))
    }

    /// Lock state for each tier plus a human-readable reason for locked ones.
    /// `xp` adds "· 420 XP to go" to the level reason when known.
    static func availability(
        tallies: [Difficulty: TierTally],
        xp: Int?,
        level: Int,
        config: GatingConfig = .standard,
        noun: String = "cards",
        verb: String = "Master"
    ) -> [TierAvailability] {
        let easy = tallies[.easy] ?? TierTally()
        let medium = tallies[.medium] ?? TierTally()

        let easyShort = shortfall(easy, fraction: config.mediumUnlockFraction)
        let mediumOpen = easyShort == 0
        let mediumShort = shortfall(medium, fraction: config.hardUnlockFraction)
        let levelOK = level >= config.hardMinimumLevel
        let hardOpen = mediumOpen && mediumShort == 0 && levelOK

        var hardReasons: [String] = []
        if !mediumOpen {
            hardReasons.append("Unlock Medium first")
        } else if mediumShort > 0 {
            hardReasons.append("\(verb) \(mediumShort) more Medium \(noun)")
        }
        if !levelOK {
            var reason = "Reach Level \(config.hardMinimumLevel)"
            if let xp {
                let needed = (config.hardMinimumLevel - 1) * LevelCalculator.xpPerLevel - max(xp, 0)
                if needed > 0 { reason += " · \(needed) XP to go" }
            }
            hardReasons.append(reason)
        }

        return [
            TierAvailability(difficulty: .easy, isUnlocked: true),
            TierAvailability(
                difficulty: .medium,
                isUnlocked: mediumOpen,
                lockReason: mediumOpen ? nil : "\(verb) \(easyShort) more Easy \(noun)"
            ),
            TierAvailability(
                difficulty: .hard,
                isUnlocked: hardOpen,
                lockReason: hardOpen ? nil : hardReasons.joined(separator: " · ")
            ),
        ]
    }

    /// Retired items still needed: ceil(fraction × total) − retired, ≥ 0.
    static func shortfall(_ tally: TierTally, fraction: Double) -> Int {
        let required = Int((fraction * Double(tally.total)).rounded(.up))
        return max(required - tally.retired, 0)
    }

    /// Starter-deck tallies: active cards by tier; retired = retiredAt set.
    /// Untagged cards count as Easy (starter cards are always tagged).
    static func tallies(for deck: FlashcardDeck) -> [Difficulty: TierTally] {
        var result: [Difficulty: TierTally] = [:]
        for card in deck.activeCards {
            let tier = card.difficulty ?? .easy
            result[tier, default: TierTally()].total += 1
            if card.retiredAt != nil {
                result[tier, default: TierTally()].retired += 1
            }
        }
        return result
    }

    /// Open tiers for a deck. User decks are never locked (D9).
    static func unlockedTiers(for deck: FlashcardDeck, level: Int, config: GatingConfig = .standard) -> Set<Difficulty> {
        guard deck.origin == .starter else { return Set(Difficulty.allCases) }
        return unlockedTiers(tallies: tallies(for: deck), level: level, config: config)
    }
}
