import Foundation

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

    /// Consecutive days with the goal met, ending on `date`'s day.
    ///
    /// Today counts only once its goal is met, but an unmet today doesn't
    /// break the streak: otherwise it would drop to 0 at midnight, before
    /// the learner has had a chance to study. So the count starts at today
    /// if met, else at yesterday.
    static func currentStreak(
        endingOn date: Date,
        activity: [DailyActivity],
        goal: Int = GatingConfig.standard.dailyGoal,
        calendar: Calendar = .current
    ) -> Int {
        let metDays = Set(activity.filter { isGoalMet($0, goal: goal) }.map(\.day))
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
}
