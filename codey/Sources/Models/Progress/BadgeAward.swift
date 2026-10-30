import Foundation
import SwiftData

extension CodeySchemaV7 {
    /// A badge the learner has earned (FR-35). Stored rather than derived so
    /// a badge stays earned when the data behind it changes (a deck is
    /// deleted, a streak ends). Local only (D10). Cleared by Reset Progress.
    @Model
    final class BadgeAward {
        /// `Badge.rawValue`; one row per badge.
        @Attribute(.unique) var badgeRaw: String
        var earnedAt: Date

        init(badge: Badge, earnedAt: Date) {
            self.badgeRaw = badge.rawValue
            self.earnedAt = earnedAt
        }
    }
}

extension BadgeAward {
    var badge: Badge? { Badge(rawValue: badgeRaw) }
}
