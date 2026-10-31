import Foundation
import SwiftData

extension CodeySchemaV3 {
    /// A study session that can be resumed (D8: the Home "Continue studying"
    /// accessory, Stage 7). At most one per deck. Deleted when the session
    /// finishes. Local only (D10).
    @Model
    final class StudyProgressSnapshot {
        @Attribute(.unique) var deckId: UUID
        /// The session queue, including "Again" re-queues.
        var cardIDs: [UUID]
        /// Index of the next card to show.
        var position: Int
        /// Cards already re-queued once (FR-17 "Again" re-queues only once).
        var requeuedIDs: [UUID]
        /// Raw Difficulty of the tier filter; nil = every available tier.
        var tierFilterRaw: String?
        /// Summary stats so far.
        var reviewedCount: Int
        var newlyMasteredIDs: [UUID]
        var startMasteryRate: Double
        /// Raw Difficulty values unlocked when the session started, to detect
        /// an unlock across a resume.
        var startUnlockedTiersRaw: [String]
        var updatedAt: Date

        /// An empty session; the view model fills it in before saving.
        init(deckId: UUID) {
            self.deckId = deckId
            cardIDs = []
            position = 0
            requeuedIDs = []
            reviewedCount = 0
            newlyMasteredIDs = []
            startMasteryRate = 0
            startUnlockedTiersRaw = []
            updatedAt = .now
        }
    }
}

extension CodeySchemaV8 {
    /// V8 (S19): the summary reports cards that moved up and deck progress
    /// in mastery points, so the snapshot keeps each card's score from the
    /// session start instead of the newly mastered IDs and mastery rate.
    @Model
    final class StudyProgressSnapshot {
        @Attribute(.unique) var deckId: UUID
        /// The session queue, including "Again" re-queues.
        var cardIDs: [UUID]
        /// Index of the next card to show.
        var position: Int
        /// Cards already re-queued once (FR-17 "Again" re-queues only once).
        var requeuedIDs: [UUID]
        /// Raw Difficulty of the tier filter; nil = every available tier.
        var tierFilterRaw: String?
        /// Summary stats so far.
        var reviewedCount: Int
        /// Mastery score of each rated card before its first rating this
        /// session, as parallel arrays (card ID, score).
        var startScoreCardIDs: [UUID] = []
        var startScores: [Int] = []
        var startProgressRate: Double = 0
        /// Raw Difficulty values unlocked when the session started, to detect
        /// an unlock across a resume.
        var startUnlockedTiersRaw: [String]
        var updatedAt: Date

        /// An empty session; the view model fills it in before saving.
        init(deckId: UUID) {
            self.deckId = deckId
            cardIDs = []
            position = 0
            requeuedIDs = []
            reviewedCount = 0
            startScoreCardIDs = []
            startScores = []
            startProgressRate = 0
            startUnlockedTiersRaw = []
            updatedAt = .now
        }
    }
}

extension StudyProgressSnapshot {
    var tierFilter: Difficulty? { tierFilterRaw.flatMap(Difficulty.init(rawValue:)) }

    /// The saved queue, for the "Card 7 of 12" counters on Home and the deck
    /// screen (repeats aren't counted as new cards).
    var queue: StudyQueue { StudyQueue(cardIDs: cardIDs, position: position, requeued: Set(requeuedIDs)) }

    /// Start-of-session mastery scores keyed by card.
    var startScoresByCard: [UUID: Int] {
        Dictionary(zip(startScoreCardIDs, startScores), uniquingKeysWith: { first, _ in first })
    }

    static func fetch(deckId: UUID, context: ModelContext) throws -> StudyProgressSnapshot? {
        try context.first(#Predicate { $0.deckId == deckId })
    }
}
