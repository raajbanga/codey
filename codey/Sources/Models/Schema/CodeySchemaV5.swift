import SwiftData

/// V5 (Stage 7): UserProfile gains pinnedTopicIds (onboarding, D16).
enum CodeySchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CodeySchemaV5.UserProfile.self,
            CodeySchemaV1.Topic.self,
            CodeySchemaV1.Question.self,
            CodeySchemaV2.FlashcardDeck.self,
            CodeySchemaV2.Flashcard.self,
            CodeySchemaV3.StudyProgressSnapshot.self,
            CodeySchemaV3.DailyActivity.self,
            CodeySchemaV4.QuestionProgress.self,
            CodeySchemaV4.TopicProgress.self,
            CodeySchemaV4.QuizAnswerRecord.self,
        ]
    }
}
