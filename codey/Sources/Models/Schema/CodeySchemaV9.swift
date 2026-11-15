import Foundation
import SwiftData

/// V9 (S41, the game layer): UserProfile remembers which rewards it has
/// already been paid, so XP for exercises and quest bonuses can't be
/// farmed. Everything else is reused from earlier versions.
enum CodeySchemaV9: VersionedSchema {
    static let versionIdentifier = Schema.Version(9, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CodeySchemaV9.UserProfile.self,
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

    @Model
    final class UserProfile {
        var id: UUID
        var username: String
        var totalXP: Int
        /// Topic ids pinned in onboarding / the profile sheet, in pick order.
        var pinnedTopicIds: [String] = []
        /// FR-04: one of the allowed SF Symbol names, or nil for the default.
        var avatarId: String?
        /// Exercises already paid for: XP comes the first time one is solved.
        var solvedExerciseIds: [String] = []
        /// Local day ("yyyy-MM-dd") the daily-goal bonus was last paid.
        var goalBonusDay: String?
        /// UTC Monday ("yyyy-MM-dd") the weekly-challenge bonus was last paid.
        var challengeBonusWeek: String?

        init(
            id: UUID = UUID(),
            username: String,
            totalXP: Int = 0,
            pinnedTopicIds: [String] = [],
            avatarId: String? = nil
        ) {
            self.id = id
            self.username = username
            self.totalXP = totalXP
            self.pinnedTopicIds = pinnedTopicIds
            self.avatarId = avatarId
        }
    }
}
