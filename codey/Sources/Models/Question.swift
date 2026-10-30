import Foundation
import SwiftData

/// Question/card tier (FR-24). Stored by raw value in SwiftData and Supabase,
/// so the cases must not be renamed.
enum Difficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard
}

extension CodeySchemaV1 {
    /// Frozen in V1. Changing a stored property needs a new schema version.
    @Model
    final class Question {
        @Attribute(.unique) var id: String
        var prompt: String
        var options: [String]
        var correctOptionIndex: Int
        var explanation: String
        var difficulty: Difficulty
        var topic: Topic?

        init(
            id: String,
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
}
