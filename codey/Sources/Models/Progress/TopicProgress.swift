import Foundation
import SwiftData

extension CodeySchemaV4 {
    /// Quiz tier unlocks per topic (FR-25/26). STICKY: once unlocked, a tier
    /// never relocks, even when reviews (FR-28) lower the retired count.
    @Model
    final class TopicProgress {
        @Attribute(.unique) var topicId: String
        var mediumUnlockedAt: Date?
        var hardUnlockedAt: Date?

        init(topicId: String) {
            self.topicId = topicId
        }
    }
}

extension TopicProgress {
    /// Tiers unlocked so far (Easy is always open).
    var unlockedTiers: Set<Difficulty> {
        var tiers: Set<Difficulty> = [.easy]
        if mediumUnlockedAt != nil { tiers.insert(.medium) }
        if hardUnlockedAt != nil { tiers.insert(.hard) }
        return tiers
    }

    /// Records newly unlocked tiers; returns the ones that are new.
    @discardableResult
    func unlock(_ tiers: Set<Difficulty>, at date: Date) -> [Difficulty] {
        var new: [Difficulty] = []
        if tiers.contains(.medium), mediumUnlockedAt == nil {
            mediumUnlockedAt = date
            new.append(.medium)
        }
        if tiers.contains(.hard), hardUnlockedAt == nil {
            hardUnlockedAt = date
            new.append(.hard)
        }
        return new
    }
}
