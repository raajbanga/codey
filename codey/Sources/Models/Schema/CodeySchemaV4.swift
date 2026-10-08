import SwiftData

/// V4 adds quiz progress (Stage 6): per-question retirement, sticky topic
/// unlocks, and the answer history for accuracy. Earlier models are reused.
enum CodeySchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CodeySchemaV1.UserProfile.self,
            CodeySchemaV1.Topic.self,
            CodeySchemaV1.Question.self,
            CodeySchemaV2.FlashcardDeck.self,
            CodeySchemaV2.Flashcard.self,
            CodeySchemaV3.StudyProgressSnapshot.self,
            CodeySchemaV3.DailyActivity.self,
            QuestionProgress.self,
            TopicProgress.self,
            QuizAnswerRecord.self,
        ]
    }
}
