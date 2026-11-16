import Foundation

/// Which cards a study session draws from (FR-16, FR-29, D9).
enum StudyPool {
    /// - Starter decks: active cards that aren't retired and are in an
    ///   unlocked tier.
    /// - User decks: every active card (never locked, never retired).
    /// - Hidden cards (§3b) are never drawn.
    /// - `tierFilter` narrows either to one tier (FR-29 restricted mode).
    /// Deck order (sortIndex) is kept: the builder lets users order cards.
    static func cards(
        in deck: FlashcardDeck,
        unlockedTiers: Set<Difficulty>,
        tierFilter: Difficulty?
    ) -> [Flashcard] {
        deck.activeCards.filter { card in
            if card.isHidden { return false }
            if let tierFilter, card.difficulty != tierFilter { return false }
            guard deck.origin == .starter else { return true }
            return card.retiredAt == nil && unlockedTiers.contains(card.difficulty ?? .easy)
        }
    }

    /// Tiers a picker can offer for this deck: tagged tiers that are present,
    /// in Easy → Hard order. Empty means "no picker" (untagged user deck).
    static func taggedTiers(in deck: FlashcardDeck) -> [Difficulty] {
        let present = Set(deck.unorderedActiveCards.compactMap(\.difficulty))
        return Difficulty.allCases.filter(present.contains)
    }
}
