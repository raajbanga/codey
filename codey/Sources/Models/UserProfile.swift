import Foundation
import SwiftData

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
