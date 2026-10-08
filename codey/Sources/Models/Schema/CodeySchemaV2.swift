import SwiftData

/// V2 adds user/starter flashcard decks (Stage 1). V1 models are unchanged
/// and reused as-is; only new or changed models are declared here.
enum CodeySchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CodeySchemaV1.UserProfile.self,
            CodeySchemaV1.Topic.self,
            CodeySchemaV1.Question.self,
            FlashcardDeck.self,
            Flashcard.self,
        ]
    }
}
