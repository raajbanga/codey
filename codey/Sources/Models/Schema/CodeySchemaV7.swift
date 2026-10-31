import SwiftData

/// V7 (Sprint 3, S3-B): UserProfile drops the stored streak and gains an
/// avatar; BadgeAward is new. Earlier models are reused.
enum CodeySchemaV7: VersionedSchema {
    static let versionIdentifier = Schema.Version(7, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CodeySchemaV7.UserProfile.self,
            CodeySchemaV1.Topic.self,
            CodeySchemaV1.Question.self,
            CodeySchemaV2.FlashcardDeck.self,
            CodeySchemaV2.Flashcard.self,
            CodeySchemaV3.StudyProgressSnapshot.self,
            CodeySchemaV3.DailyActivity.self,
            CodeySchemaV4.QuestionProgress.self,
            CodeySchemaV4.TopicProgress.self,
            CodeySchemaV4.QuizAnswerRecord.self,
            CodeySchemaV6.SyncOperation.self,
            CodeySchemaV7.BadgeAward.self,
        ]
    }
}
