import Foundation
import SwiftData

extension CodeySchemaV4 {
    /// One graded quiz answer. Feeds FR-36 accuracy (last 50 per topic);
    /// pruned to the last 200 per topic. Local only (D10).
    @Model
    final class QuizAnswerRecord {
        var questionId: String
        var topicId: String
        var correct: Bool
        var answeredAt: Date

        init(questionId: String, topicId: String, correct: Bool, answeredAt: Date) {
            self.questionId = questionId
            self.topicId = topicId
            self.correct = correct
            self.answeredAt = answeredAt
        }
    }
}
