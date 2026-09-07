import Foundation
import SwiftData

enum Difficulty: String, Codable {
    case easy
    case medium
    case hard
}

@Model
final class Question {
    var id: UUID
    var prompt: String
    var options: [String]
    var correctOptionIndex: Int
    var explanation: String
    var difficulty: Difficulty
    var topic: Topic?

    init(
        id: UUID = UUID(),
        prompt: String,
        options: [String],
        correctOptionIndex: Int,
        explanation: String,
        difficulty: Difficulty,
        topic: Topic? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.correctOptionIndex = correctOptionIndex
        self.explanation = explanation
        self.difficulty = difficulty
        self.topic = topic
    }
}
