import Foundation
import SwiftData

extension CodeySchemaV4 {
    /// Per-question quiz progress (FR-23/24/28). Local only (D10).
    @Model
    final class QuestionProgress {
        @Attribute(.unique) var questionId: String
        var topicId: String
        var difficulty: Difficulty
        var consecutiveCorrect: Int = 0
        var totalAttempts: Int = 0
        var totalCorrect: Int = 0
        /// Set after `retireAfterConsecutiveCorrect` correct answers in a row.
        var retiredAt: Date?
        /// Returned from retirement for a review (FR-28).
        var isReview: Bool = false
        var lastAnsweredAt: Date?

        init(questionId: String, topicId: String, difficulty: Difficulty) {
            self.questionId = questionId
            self.topicId = topicId
            self.difficulty = difficulty
        }
    }
}

extension QuestionProgress {
    var isRetired: Bool { retiredAt != nil }

    /// FR-28: retired at least `reviewAfterDays` ago.
    func isDueForReview(now: Date, config: GatingConfig = .standard) -> Bool {
        guard let retiredAt else { return false }
        return now >= retiredAt.addingTimeInterval(TimeInterval(config.reviewAfterDays) * 86_400)
    }

    /// FR-23/24/28. Correct: streak +1; a review retires again at once,
    /// otherwise retire at the threshold. Wrong: streak resets; a review
    /// stays active as a normal question. Returns true if this answer
    /// retired the question.
    @discardableResult
    func record(correct: Bool, at date: Date, config: GatingConfig = .standard) -> Bool {
        totalAttempts += 1
        lastAnsweredAt = date
        guard correct else {
            consecutiveCorrect = 0
            isReview = false
            return false
        }
        totalCorrect += 1
        consecutiveCorrect += 1
        guard retiredAt == nil else { return false }
        if isReview || consecutiveCorrect >= config.retireAfterConsecutiveCorrect {
            retiredAt = date
            isReview = false
            return true
        }
        return false
    }

    /// FR-28: a question retired at least `reviewAfterDays` ago comes back
    /// as a review. Returns true if it was returned.
    @discardableResult
    func returnForReviewIfDue(now: Date, config: GatingConfig = .standard) -> Bool {
        guard isDueForReview(now: now, config: config) else { return false }
        retiredAt = nil
        isReview = true
        consecutiveCorrect = 0
        return true
    }
}
