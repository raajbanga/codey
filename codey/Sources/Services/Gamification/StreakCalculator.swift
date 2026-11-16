import Foundation
import SwiftData

/// Daily goal and streak (FR-32/33). Pure, like LevelCalculator: the streak
/// is derived from DailyActivity every time instead of stored, so it can't
/// drift (Activity 10_2 tech debt: the old stored `currentStreak` was never
/// updated).
enum StreakCalculator {
    /// Quiz answers + card ratings on one day.
    static func progress(of day: DailyActivity?) -> Int {
        guard let day else { return 0 }
        return day.quizAnswers + day.cardsRated
    }

    static func isGoalMet(_ day: DailyActivity?, goal: Int = GatingConfig.standard.dailyGoal) -> Bool {
        progress(of: day) >= goal
    }

    /// Quiz answers + card ratings per day: this device's DailyActivity plus
    /// every other device's (S43, pulled into DeviceDayActivity).
    static func dayTotals(own: [DailyActivity], others: [DeviceDayActivity] = []) -> [String: Int] {
        var totals: [String: Int] = [:]
        for day in own { totals[day.day, default: 0] += day.quizAnswers + day.cardsRated }
        for day in others { totals[day.day, default: 0] += day.quizAnswers + day.cardsRated }
        return totals
    }

    /// `dayTotals` for the given day keys, read from the store.
    static func dayTotals(for days: [String], context: ModelContext) throws -> [String: Int] {
        dayTotals(
            own: try context.fetch(FetchDescriptor<DailyActivity>(predicate: #Predicate { days.contains($0.day) })),
            others: try context.fetch(FetchDescriptor<DeviceDayActivity>(predicate: #Predicate { days.contains($0.day) }))
        )
    }

    /// Consecutive days with the goal met, ending on `date`'s day.
    ///
    /// Today counts only once its goal is met, but an unmet today doesn't
    /// break the streak: otherwise it would drop to 0 at midnight, before
    /// the learner has had a chance to study. So the count starts at today
    /// if met, else at yesterday.
    static func currentStreak(
        endingOn date: Date,
        totals: [String: Int],
        goal: Int = GatingConfig.standard.dailyGoal,
        calendar: Calendar = .current
    ) -> Int {
        let metDays = Set(totals.filter { $0.value >= goal }.keys)
        guard !metDays.isEmpty else { return 0 }

        // Step from noon, not midnight: on a DST change the day is 23 or 25
        // hours long, and some zones skip midnight entirely.
        guard var cursor = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) else { return 0 }
        if !metDays.contains(DailyActivity.dayKey(for: cursor, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while metDays.contains(DailyActivity.dayKey(for: cursor, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// This device's activity only.
    static func currentStreak(
        endingOn date: Date,
        activity: [DailyActivity],
        goal: Int = GatingConfig.standard.dailyGoal,
        calendar: Calendar = .current
    ) -> Int {
        currentStreak(endingOn: date, totals: dayTotals(own: activity), goal: goal, calendar: calendar)
    }
}
