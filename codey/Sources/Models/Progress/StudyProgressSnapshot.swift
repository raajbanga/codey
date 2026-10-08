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

extension StudyProgressSnapshot {
    var tierFilter: Difficulty? { tierFilterRaw.flatMap(Difficulty.init(rawValue:)) }

    /// "7/12"-style progress for the accessory and the deck screen.
    var displayPosition: Int { min(position + 1, cardIDs.count) }

    static func fetch(deckId: UUID, context: ModelContext) throws -> StudyProgressSnapshot? {
        try context.first(#Predicate { $0.deckId == deckId })
    }
}
