import Foundation
import SwiftData

extension CodeySchemaV1 {
    /// Frozen in V1. Changing a stored property needs a new schema version.
    @Model
    final class Topic {
        @Attribute(.unique) var id: String
        var title: String
        var summary: String
        var iconName: String
        @Relationship(deleteRule: .cascade, inverse: \Question.topic)
        var questions: [Question]

        init(
            id: String,
            title: String,
            summary: String,
            iconName: String,
            questions: [Question] = []
        ) {
            self.id = id
            self.title = title
            self.summary = summary
            self.iconName = iconName
            self.questions = questions
        }
    }
}
