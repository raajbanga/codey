import SwiftData

/// Every shipped schema, oldest first. To change a model: freeze the current
/// version, add CodeySchemaV(n+1), append a stage here, and repoint the
/// typealiases below. Never edit a schema that has shipped.
enum CodeyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CodeySchemaV1.self, CodeySchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2]
    }

    /// Additive only (new deck/card entities), so lightweight is enough.
    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: CodeySchemaV1.self,
        toVersion: CodeySchemaV2.self
    )
}

typealias CodeySchemaCurrent = CodeySchemaV2

// The rest of the app always uses these names, never the versioned ones.
typealias UserProfile = CodeySchemaV1.UserProfile
typealias Topic = CodeySchemaV1.Topic
typealias Question = CodeySchemaV1.Question
typealias FlashcardDeck = CodeySchemaV2.FlashcardDeck
typealias Flashcard = CodeySchemaV2.Flashcard
