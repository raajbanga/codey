import Foundation

// MARK: - [Pattern: Factory] Creation input
/// The one wire/bundle DTO for a card (FR-09): starter JSON, sync, and
/// toPayload() all use it. A typed stand-in for the UML's "Dictionary".
/// Its JSON shape is documented in Resources/Schemas/flashcard.schema.json.
struct FlashcardPayload: Codable, Equatable {
    var id: UUID?
    var prompt: String
    var answer: String
    /// CodeLanguage raw value; present iff codeSource is.
    var codeLanguage: String?
    var codeSource: String?
    var difficulty: Difficulty?
    var sortIndex: Int
    var masteryScore: Int?
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?

    init(
        id: UUID? = nil,
        prompt: String,
        answer: String,
        codeLanguage: String? = nil,
        codeSource: String? = nil,
        difficulty: Difficulty? = nil,
        sortIndex: Int = 0,
        masteryScore: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.codeLanguage = codeLanguage
        self.codeSource = codeSource
        self.difficulty = difficulty
        self.sortIndex = sortIndex
        self.masteryScore = masteryScore
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
