import SwiftData

/// Every shipped schema, oldest first. To change a model: freeze the current
/// version, add CodeySchemaV(n+1), append a stage here, and repoint the
/// typealiases below. Never edit a schema that has shipped.
enum CodeyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CodeySchemaV1.self, CodeySchemaV2.self, CodeySchemaV3.self, CodeySchemaV4.self, CodeySchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2, v2ToV3, v3ToV4, v4ToV5]
    }

    /// Additive only (new deck/card entities), so lightweight is enough.
    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: CodeySchemaV1.self,
        toVersion: CodeySchemaV2.self
    )

    /// Additive only (study snapshot + daily activity).
    static let v2ToV3 = MigrationStage.lightweight(
        fromVersion: CodeySchemaV2.self,
        toVersion: CodeySchemaV3.self
    )

    /// Additive only (quiz progress models).
    static let v3ToV4 = MigrationStage.lightweight(
        fromVersion: CodeySchemaV3.self,
        toVersion: CodeySchemaV4.self
    )

    /// UserProfile gains pinnedTopicIds with a default, so lightweight.
    static let v4ToV5 = MigrationStage.lightweight(
        fromVersion: CodeySchemaV4.self,
        toVersion: CodeySchemaV5.self
    )
}

typealias CodeySchemaCurrent = CodeySchemaV5

// The rest of the app always uses these names, never the versioned ones.
typealias UserProfile = CodeySchemaV5.UserProfile
typealias Topic = CodeySchemaV1.Topic
typealias Question = CodeySchemaV1.Question
typealias FlashcardDeck = CodeySchemaV2.FlashcardDeck
typealias Flashcard = CodeySchemaV2.Flashcard
typealias StudyProgressSnapshot = CodeySchemaV3.StudyProgressSnapshot
typealias DailyActivity = CodeySchemaV3.DailyActivity
typealias QuestionProgress = CodeySchemaV4.QuestionProgress
typealias TopicProgress = CodeySchemaV4.TopicProgress
typealias QuizAnswerRecord = CodeySchemaV4.QuizAnswerRecord
