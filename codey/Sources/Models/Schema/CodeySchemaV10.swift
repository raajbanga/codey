import Foundation
import SwiftData

/// V10 (S43, progress sync): other devices' daily counters, so the daily
/// goal and streak count study done on every device. This device's own
/// counters stay in DailyActivity (they're what it pushes); everything else
/// is reused from earlier versions.
enum CodeySchemaV10: VersionedSchema {
    static let versionIdentifier = Schema.Version(10, 0, 0)

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
            CodeySchemaV10.DeviceDayActivity.self,
        ]
    }

    /// One other device's counters for one local day, pulled from
    /// daily_activity. The day's total is DailyActivity plus these rows.
    @Model
    final class DeviceDayActivity {
        /// "deviceId|day", one row per device and day.
        @Attribute(.unique) var key: String
        var deviceId: String
        /// Local calendar day, "yyyy-MM-dd" (as DailyActivity.day).
        var day: String
        var cardsRated: Int = 0
        var quizAnswers: Int = 0

        init(deviceId: String, day: String) {
            self.key = "\(deviceId)|\(day)"
            self.deviceId = deviceId
            self.day = day
        }
    }
}
