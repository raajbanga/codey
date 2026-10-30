import Foundation
import SwiftData

extension CodeySchemaV1 {
    /// Frozen in V1. Changing a stored property needs a new schema version.
    @Model
    final class UserProfile {
        var id: UUID
        var username: String
        var totalXP: Int
        var currentStreak: Int
        var lastActiveDate: Date?

        init(
            id: UUID = UUID(),
            username: String,
            totalXP: Int = 0,
            currentStreak: Int = 0,
            lastActiveDate: Date? = nil
        ) {
            self.id = id
            self.username = username
            self.totalXP = totalXP
            self.currentStreak = currentStreak
            self.lastActiveDate = lastActiveDate
        }
    }
}

extension UserProfile {
    static let defaultUsername = "Codey Learner"

    var level: Int { LevelCalculator.level(forXP: totalXP) }
}

extension CodeySchemaV5 {
    /// V5 adds the topics picked in onboarding (D16). Everything else is
    /// unchanged from V1.
    @Model
    final class UserProfile {
        var id: UUID
        var username: String
        var totalXP: Int
        var currentStreak: Int
        var lastActiveDate: Date?
        /// Topic ids pinned in onboarding / the profile sheet, in pick order.
        var pinnedTopicIds: [String] = []

        init(
            id: UUID = UUID(),
            username: String,
            totalXP: Int = 0,
            currentStreak: Int = 0,
            lastActiveDate: Date? = nil,
            pinnedTopicIds: [String] = []
        ) {
            self.id = id
            self.username = username
            self.totalXP = totalXP
            self.currentStreak = currentStreak
            self.lastActiveDate = lastActiveDate
            self.pinnedTopicIds = pinnedTopicIds
        }
    }
}

extension CodeySchemaV7 {
    /// V7 (Sprint 3) drops the stored `currentStreak` / `lastActiveDate`:
    /// nothing ever updated them (Activity 10_2 tech debt), and the streak
    /// is now derived from DailyActivity by StreakCalculator. Adds the
    /// FR-04 avatar (an SF Symbol name; matches profiles.avatar_id).
    @Model
    final class UserProfile {
        var id: UUID
        var username: String
        var totalXP: Int
        /// Topic ids pinned in onboarding / the profile sheet, in pick order.
        var pinnedTopicIds: [String] = []
        /// FR-04: one of the allowed SF Symbol names, or nil for the default.
        var avatarId: String?

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
