import Foundation
import SwiftData

@Model
final class Topic {
    var id: UUID
    var title: String
    var summary: String
    var iconName: String
    @Relationship(deleteRule: .cascade, inverse: \Question.topic)
    var questions: [Question]

    init(
        id: UUID = UUID(),
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
