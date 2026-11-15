import Foundation
import Observation
import SwiftData
import os

/// One flashcard study session (FR-16/17/18, UC-04).
///
/// Flow: show the prompt → reveal → rate → mastery saved → next card. The
/// session is snapshotted after every rating, so it can be resumed (D8), and
/// the snapshot is deleted when the queue runs out.
@MainActor
@Observable
final class StudySessionViewModel {
    enum Start: Equatable {
        /// New session. Replaces any saved snapshot for the deck.
        case fresh(tierFilter: Difficulty?)
        /// Continue the saved snapshot; falls back to a fresh, unfiltered
        /// session if there isn't one (or nothing in it is left).
        case resume
    }

    /// What one rating did, for haptics and the "Mastered" chip.
    struct RatingOutcome: Equatable {
        let id = UUID()
        let rating: CardRating
        let cardID: UUID
        /// Mastery score before and after the rating (the card's dots, S19).
        let previousScore: Int
        let newScore: Int
        let becameMastered: Bool
        /// Starter card retired by this rating (D9).
        let retired: Bool
        /// XP this rating paid: the card moving up, plus any quest bonus (S41).
        var xp = 0
        var bonuses: [XPRewards.Bonus] = []
    }

    struct Summary: Equatable {
        /// Distinct cards rated; "Again" repeats are counted in `repeats`,
        /// so a 4-card session reports 4, not 5 (S19).
        var reviewed: Int
        var repeats: Int
        /// Cards whose mastery score ended higher than it started (S19).
        var movedUp: Int
        var newlyMastered: Int
        /// Deck progress (FlashcardDeck.progressRate) before and after.
        var startProgressRate: Double
        var endProgressRate: Double
        /// Tiers this session unlocked (starter decks), Easy → Hard.
        var unlockedTiers: [Difficulty]
        /// XP earned this session (S41).
        var xpEarned = 0

        var progressDelta: Double { endProgressRate - startProgressRate }
    }

    let deck: FlashcardDeck
    private(set) var tierFilter: Difficulty?
    private(set) var queue = StudyQueue(cardIDs: [])
    private(set) var isRevealed = false
    /// Whether the current card's answer has been shown at least once, so
    /// ratings stay available after flipping back to the prompt.
    private(set) var hasRevealedCurrent = false
    private(set) var lastOutcome: RatingOutcome?
    /// Set when the queue runs out (or was empty from the start).
    private(set) var summary: Summary?

    private let context: ModelContext
    private let now: () -> Date
    private let config: GatingConfig
    private let weeklyXP: WeeklyXPStore
    private(set) var xpEarned = 0
    private var cardsByID: [UUID: Flashcard] = [:]
    private var reviewedCount = 0
    /// Each rated card's score before its first rating this session.
    private var startScores: [UUID: Int] = [:]
    private var startProgressRate = 0.0
    private var startUnlockedTiers: Set<Difficulty> = []

    init(
        deck: FlashcardDeck,
        start: Start,
        context: ModelContext,
        config: GatingConfig = .standard,
        weeklyXP: WeeklyXPStore = WeeklyXPStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.deck = deck
        self.context = context
        self.config = config
        self.weeklyXP = weeklyXP
        self.now = now
        refreshCardIndex()

        switch start {
        case .resume:
            if !resumeFromSnapshot() { begin(tierFilter: nil) }
        case .fresh(let filter):
            begin(tierFilter: filter)
        }
    }

    // MARK: State

    var currentCard: Flashcard? { queue.current.flatMap { cardsByID[$0] } }
    var isFinished: Bool { summary != nil }
    /// Nothing to study at all (e.g. every unlocked starter card is retired).
    var wasEmpty: Bool { isFinished && reviewedCount == 0 && queue.total == 0 }

    /// Open tiers for this deck (starter decks are gated, D9), as of the
    /// session's start or finish. Tiers only change on a rating, and only
    /// the summary reports them, so they aren't recomputed per access.
    private(set) var unlockedTiers: Set<Difficulty> = []

    // MARK: Actions

    /// Tap / Space: flips between prompt and answer. Rating needs the answer
    /// to have been revealed (FR-16).
    func toggleReveal() {
        guard currentCard != nil else { return }
        isRevealed.toggle()
        if isRevealed { hasRevealedCurrent = true }
    }

    /// Rates the current card (FR-17), applies mastery (FR-18), saves, and
    /// advances. Returns nil if the answer hasn't been revealed.
    @discardableResult
    func rate(_ rating: CardRating) -> RatingOutcome? {
        guard hasRevealedCurrent, let card = currentCard else { return nil }
        let timestamp = now()

        let wasMastered = card.isMastered
        let wasRetired = card.retiredAt != nil
        let previousScore = card.masteryScore
        if startScores[card.id] == nil { startScores[card.id] = previousScore }
        card.updateMastery(rating: rating, at: timestamp)
        var outcome = RatingOutcome(
            rating: rating,
            cardID: card.id,
            previousScore: previousScore,
            newScore: card.masteryScore,
            becameMastered: !wasMastered && card.isMastered,
            retired: !wasRetired && card.retiredAt != nil
        )
        reviewedCount += 1
        queue.record(rating)
        isRevealed = false
        hasRevealedCurrent = false
        lastOutcome = outcome

        do {
            try DailyActivity.forDay(timestamp, context: context).cardsRated += 1
            // XP for a card that moved up, then any quest bonus (S41).
            let profile = DataSeeder.ensureProfile(context: context)
            outcome.xp = XPRewards.forCard(previousScore: previousScore, newScore: card.masteryScore)
            XPRewards.grant(outcome.xp, to: profile, weeklyXP: weeklyXP, now: timestamp)
            outcome.bonuses = try XPRewards.payQuestBonuses(context: context, profile: profile, weeklyXP: weeklyXP, now: timestamp)
            outcome.xp += outcome.bonuses.map(\.amount).reduce(0, +)
            xpEarned += outcome.xp
            lastOutcome = outcome
            // A rating can complete the daily goal → streak badge (FR-35).
            try BadgeEvaluator.award(context: context, now: timestamp)
            if queue.isFinished {
                finish()
            } else {
                try writeSnapshot(at: timestamp)
            }
            try context.save()
        } catch {
            Logger.study.error("Saving a rating failed: \(String(describing: error))")
        }
        return outcome
    }

    /// "Study again": a fresh session with the same tier filter.
    func restart() {
        begin(tierFilter: tierFilter)
    }

    // MARK: Session lifecycle

    private func begin(tierFilter: Difficulty?) {
        self.tierFilter = tierFilter
        deleteSnapshot()
        refreshCardIndex()
        refreshUnlockedTiers()
        let pool = StudyPool.cards(in: deck, unlockedTiers: unlockedTiers, tierFilter: tierFilter)
        queue = StudyQueue(cardIDs: pool.map(\.id))
        resetStats()
        if queue.isFinished { finish() }
        saveQuietly()
    }

    private func resumeFromSnapshot() -> Bool {
        guard let snapshot = try? StudyProgressSnapshot.fetch(deckId: deck.id, context: context) else { return false }
        var restored = StudyQueue(
            cardIDs: snapshot.cardIDs,
            position: snapshot.position,
            requeued: Set(snapshot.requeuedIDs)
        )
        restored.retain(only: Set(cardsByID.keys))
        guard !restored.isFinished else { return false }

        tierFilter = snapshot.tierFilter
        queue = restored
        reviewedCount = snapshot.reviewedCount
        startScores = snapshot.startScoresByCard
        startProgressRate = snapshot.startProgressRate
        startUnlockedTiers = Set(snapshot.startUnlockedTiersRaw.compactMap(Difficulty.init(rawValue:)))
        refreshUnlockedTiers()
        isRevealed = false
        hasRevealedCurrent = false
        summary = nil
        return true
    }

    private func resetStats() {
        reviewedCount = 0
        xpEarned = 0
        startScores = [:]
        startProgressRate = deck.progressRate
        startUnlockedTiers = unlockedTiers
        isRevealed = false
        hasRevealedCurrent = false
        lastOutcome = nil
        summary = nil
    }

    private func finish() {
        refreshUnlockedTiers()
        let endUnlocked = unlockedTiers
        // Compared with the start score, so a card raised and then reset by
        // "Again" counts as neither moved up nor mastered.
        let movedUp = startScores.filter { id, start in (cardsByID[id]?.masteryScore ?? start) > start }
        summary = Summary(
            reviewed: queue.distinctTotal,
            repeats: queue.repeatCount,
            movedUp: movedUp.count,
            newlyMastered: movedUp.keys.filter { cardsByID[$0]?.isMastered == true }.count,
            startProgressRate: startProgressRate,
            endProgressRate: deck.progressRate,
            unlockedTiers: Difficulty.allCases.filter { endUnlocked.contains($0) && !startUnlockedTiers.contains($0) },
            xpEarned: xpEarned
        )
        deleteSnapshot()
    }

    // MARK: Persistence

    private func writeSnapshot(at timestamp: Date) throws {
        let snapshot = try StudyProgressSnapshot.fetch(deckId: deck.id, context: context) ?? {
            let new = StudyProgressSnapshot(deckId: deck.id)
            context.insert(new)
            return new
        }()
        snapshot.cardIDs = queue.cardIDs
        snapshot.position = queue.position
        snapshot.requeuedIDs = Array(queue.requeued)
        snapshot.tierFilterRaw = tierFilter?.rawValue
        snapshot.reviewedCount = reviewedCount
        snapshot.startScoreCardIDs = Array(startScores.keys)
        snapshot.startScores = snapshot.startScoreCardIDs.map { startScores[$0] ?? 0 }
        snapshot.startProgressRate = startProgressRate
        snapshot.startUnlockedTiersRaw = startUnlockedTiers.map(\.rawValue)
        snapshot.updatedAt = timestamp
    }

    private func deleteSnapshot() {
        do {
            if let snapshot = try StudyProgressSnapshot.fetch(deckId: deck.id, context: context) {
                context.delete(snapshot)
            }
        } catch {
            Logger.study.error("Reading the study snapshot failed: \(String(describing: error))")
        }
    }

    private func saveQuietly() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Logger.study.error("Saving the study session failed: \(String(describing: error))")
        }
    }

    private func refreshCardIndex() {
        cardsByID = deck.unorderedActiveCards.keyed(by: \.id)
    }

    private func refreshUnlockedTiers() {
        let profile: UserProfile? = try? context.first()
        unlockedTiers = TierGate.unlockedTiers(for: deck, level: profile?.level ?? 1, config: config)
    }
}
