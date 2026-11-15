import SwiftData

/// Every shipped schema, oldest first. To change a model: freeze the current
/// version, add CodeySchemaV(n+1), append a stage here, and repoint the
/// typealiases below. Never edit a schema that has shipped.
enum CodeyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CodeySchemaV1.self, CodeySchemaV2.self, CodeySchemaV3.self, CodeySchemaV4.self, CodeySchemaV5.self,
         CodeySchemaV6.self, CodeySchemaV7.self, CodeySchemaV8.self, CodeySchemaV9.self,
         CodeySchemaV10.self, CodeySchemaV11.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2, v2ToV3, v3ToV4, v4ToV5, v5ToV6, v6ToV7, v7ToV8, v8ToV9, v9ToV10, v10ToV11]
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

    /// Additive only (sync queue).
    static let v5ToV6 = MigrationStage.lightweight(
        fromVersion: CodeySchemaV5.self,
        toVersion: CodeySchemaV6.self
    )

    /// UserProfile drops two never-updated columns (currentStreak,
    /// lastActiveDate) and gains an optional avatar; BadgeAward is new.
    /// Removing columns and adding optional ones is lightweight.
    static let v6ToV7 = MigrationStage.lightweight(
        fromVersion: CodeySchemaV6.self,
        toVersion: CodeySchemaV7.self
    )

    /// StudyProgressSnapshot drops newlyMasteredIDs and startMasteryRate and
    /// gains start scores with defaults (S19), so lightweight. An in-progress
    /// session resumes with no start scores: cards rated before the update
    /// count from their current score.
    static let v7ToV8 = MigrationStage.lightweight(
        fromVersion: CodeySchemaV7.self,
        toVersion: CodeySchemaV8.self
    )

    /// UserProfile gains reward bookkeeping with defaults (S41), so
    /// lightweight.
    static let v8ToV9 = MigrationStage.lightweight(
        fromVersion: CodeySchemaV8.self,
        toVersion: CodeySchemaV9.self
    )

    /// Additive only (other devices' daily counters, S43).
    static let v9ToV10 = MigrationStage.lightweight(
        fromVersion: CodeySchemaV9.self,
        toVersion: CodeySchemaV10.self
    )

    /// Flashcard gains isHidden with a default (§3b), so lightweight.
    static let v10ToV11 = MigrationStage.lightweight(
        fromVersion: CodeySchemaV10.self,
        toVersion: CodeySchemaV11.self
    )
}

typealias CodeySchemaCurrent = CodeySchemaV11

// The rest of the app always uses these names, never the versioned ones.
typealias UserProfile = CodeySchemaV9.UserProfile
typealias Topic = CodeySchemaV1.Topic
typealias Question = CodeySchemaV1.Question
typealias FlashcardDeck = CodeySchemaV11.FlashcardDeck
typealias Flashcard = CodeySchemaV11.Flashcard
typealias StudyProgressSnapshot = CodeySchemaV8.StudyProgressSnapshot
typealias DailyActivity = CodeySchemaV3.DailyActivity
typealias QuestionProgress = CodeySchemaV4.QuestionProgress
typealias TopicProgress = CodeySchemaV4.TopicProgress
typealias QuizAnswerRecord = CodeySchemaV4.QuizAnswerRecord
typealias SyncOperation = CodeySchemaV6.SyncOperation
typealias BadgeAward = CodeySchemaV7.BadgeAward
typealias DeviceDayActivity = CodeySchemaV10.DeviceDayActivity
