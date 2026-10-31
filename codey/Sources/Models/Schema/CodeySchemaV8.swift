import SwiftData

/// V8 (Sprint 3, S19): StudyProgressSnapshot keeps start-of-session scores
/// for the "moved up" summary. Earlier models are reused.
enum CodeySchemaV8: VersionedSchema {
    static let versionIdentifier = Schema.Version(8, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CodeySchemaV7.UserProfile.self,
            CodeySchemaV1.Topic.self,
            CodeySchemaV1.Question.self,
            CodeySchemaV2.FlashcardDeck.self,
            CodeySchemaV2.Flashcard.self,
            CodeySchemaV8.StudyProgressSnapshot.self,
            CodeySchemaV3.DailyActivity.self,
            CodeySchemaV4.QuestionProgress.self,
            CodeySchemaV4.TopicProgress.self,
            CodeySchemaV4.QuizAnswerRecord.self,
            CodeySchemaV6.SyncOperation.self,
            CodeySchemaV7.BadgeAward.self,
        ]
    }
}
