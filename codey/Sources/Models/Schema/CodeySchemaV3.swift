import SwiftData

/// V3 adds study progress (Stage 5): resumable sessions and daily activity.
/// V1/V2 models are unchanged and reused as-is.
enum CodeySchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CodeySchemaV1.UserProfile.self,
            CodeySchemaV1.Topic.self,
            CodeySchemaV1.Question.self,
            CodeySchemaV2.FlashcardDeck.self,
            CodeySchemaV2.Flashcard.self,
            StudyProgressSnapshot.self,
            DailyActivity.self,
        ]
    }
}
