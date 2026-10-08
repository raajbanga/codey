import Foundation
import SwiftData

extension CodeySchemaV3 {
    /// Per-calendar-day activity counters (prep for FR-32 daily goal and a
    /// real streak). Local only (D10).
    @Model
    final class DailyActivity {
        /// Local calendar day, "yyyy-MM-dd".
        @Attribute(.unique) var day: String
        /// Flashcard self-ratings (Stage 5).
        var cardsRated: Int = 0
        /// Quiz answers (wired in Stage 6).
        var quizAnswers: Int = 0

        init(day: String) {
            self.day = day
        }
    }
}

extension DailyActivity {
    /// "yyyy-MM-dd" in the given calendar's time zone.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Fetches today's row, inserting it if missing. Does not save.
    static func forDay(_ date: Date, context: ModelContext, calendar: Calendar = .current) throws -> DailyActivity {
        let key = dayKey(for: date, calendar: calendar)
        if let existing = try context.first(#Predicate<DailyActivity> { $0.day == key }) {
            return existing
        }
        let activity = DailyActivity(day: key)
        context.insert(activity)
        return activity
    }
}
