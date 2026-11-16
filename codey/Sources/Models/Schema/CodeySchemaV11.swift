import SwiftData

/// V11 (§3b, Nov 15): a card can be hidden from study without deleting it
/// (Flashcard.isHidden, default false). Decks move with their cards, since
/// the relationship ties the two together; everything else is reused.
enum CodeySchemaV11: VersionedSchema {
    static let versionIdentifier = Schema.Version(11, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CodeySchemaV9.UserProfile.self,
            CodeySchemaV1.Topic.self,
            CodeySchemaV1.Question.self,
            CodeySchemaV11.FlashcardDeck.self,
            CodeySchemaV11.Flashcard.self,
            CodeySchemaV8.StudyProgressSnapshot.self,
            CodeySchemaV3.DailyActivity.self,
            CodeySchemaV4.QuestionProgress.self,
            CodeySchemaV4.TopicProgress.self,
            CodeySchemaV4.QuizAnswerRecord.self,
            CodeySchemaV6.SyncOperation.self,
            CodeySchemaV7.BadgeAward.self,
            CodeySchemaV10.DeviceDayActivity.self,
        ]
    }
}
