import Foundation
import SwiftData

extension CodeySchemaV11 {
    // MARK: - [Pattern: Factory] Product
    /// One prompt/answer card (FR-06, FR-07). Only FlashcardFactory can create
    /// one: the init needs a FlashcardFactory.Token, which only the factory's
    /// file can make (factory rule, §9.2).
    @Model
    final class Flashcard {
        @Attribute(.unique) var id: UUID
        /// Block markdown, 1–500 characters.
        var prompt: String
        /// Block markdown, 1–500 characters.
        var answer: String
        /// Optional main code example (D2).
        var codeSnippet: CodeSnippet?
        /// Required for starter cards, optional for user cards.
        var difficulty: Difficulty?
        var sortIndex: Int
        /// 0...5. Change it only through updateMastery / resetMastery.
        private(set) var masteryScore: Int = 0
        var lastReviewedAt: Date?
        /// Starter cards only: set when mastery reaches 5 (D9).
        var retiredAt: Date?
        var createdAt: Date
        var updatedAt: Date
        /// Tombstone (FR-13 + sync).
        var deletedAt: Date?
        /// Taken out of study (and progress) but kept in the deck (§3b, V11).
        var isHidden: Bool = false
        var deck: FlashcardDeck?

        init(
            _ token: FlashcardFactory.Token,
            id: UUID,
            prompt: String,
            answer: String,
            codeSnippet: CodeSnippet?,
            difficulty: Difficulty?,
            sortIndex: Int,
            masteryScore: Int,
            createdAt: Date,
            updatedAt: Date,
            deletedAt: Date?
        ) {
            self.id = id
            self.prompt = prompt
            self.answer = answer
            self.codeSnippet = codeSnippet
            self.difficulty = difficulty
            self.sortIndex = sortIndex
            self.masteryScore = masteryScore
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
        }

        /// Applies a self-rating (FR-18). Mastery is study progress, not
        /// content, so it doesn't bump updatedAt.
        func updateMastery(rating: CardRating, at date: Date = .now) {
            masteryScore = rating.applied(to: masteryScore)
            lastReviewedAt = date
            if isMastered {
                if deck?.origin == .starter, retiredAt == nil {
                    retiredAt = date
                }
            } else {
                retiredAt = nil
            }
        }

        /// FR-61: takes another device's newer review. The caller checks it
        /// is newer; the score is clamped to 0...5.
        func applyRemoteProgress(score: Int, lastReviewedAt: Date, retiredAt: Date?) {
            masteryScore = min(max(score, 0), Flashcard.maxMastery)
            self.lastReviewedAt = lastReviewedAt
            self.retiredAt = retiredAt
        }

        func resetMastery() {
            masteryScore = 0
            lastReviewedAt = nil
            retiredAt = nil
        }
    }
}

extension Flashcard {
    static let maxMastery = 5

    var isMastered: Bool { masteryScore >= Self.maxMastery }

    func toPayload() -> FlashcardPayload {
        FlashcardPayload(
            id: id,
            prompt: prompt,
            answer: answer,
            codeLanguage: codeSnippet?.language.rawValue,
            codeSource: codeSnippet?.source,
            difficulty: difficulty,
            sortIndex: sortIndex,
            masteryScore: masteryScore,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            isHidden: isHidden
        )
    }
}

extension CodeySchemaV2 {
    /// Frozen in V2 (stored properties only). The live model is V11's.
    @Model
    final class Flashcard {
        @Attribute(.unique) var id: UUID
        var prompt: String
        var answer: String
        var codeSnippet: CodeSnippet?
        var difficulty: Difficulty?
        var sortIndex: Int
        var masteryScore: Int = 0
        var lastReviewedAt: Date?
        var retiredAt: Date?
        var createdAt: Date
        var updatedAt: Date
        var deletedAt: Date?
        var deck: FlashcardDeck?

        init(id: UUID, prompt: String, answer: String, sortIndex: Int, createdAt: Date) {
            self.id = id
            self.prompt = prompt
            self.answer = answer
            self.sortIndex = sortIndex
            self.createdAt = createdAt
            self.updatedAt = createdAt
        }
    }
}
