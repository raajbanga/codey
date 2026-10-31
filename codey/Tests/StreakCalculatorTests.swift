import Foundation
import Testing
@testable import codey

/// FR-32/33: daily goal and the derived streak.
struct StreakCalculatorTests {
    private let chicago: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }()

    /// Noon on the given local day.
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, calendar: Calendar? = nil) -> Date {
        let calendar = calendar ?? chicago
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func activity(_ day: String, cards: Int = 0, quiz: Int = 0) -> DailyActivity {
        let row = DailyActivity(day: day)
        row.cardsRated = cards
        row.quizAnswers = quiz
        return row
    }

    @Test func goalCountsCardsAndQuizAnswersTogether() {
        #expect(StreakCalculator.progress(of: activity("2026-10-30", cards: 12, quiz: 5)) == 17)
        #expect(StreakCalculator.progress(of: nil) == 0)
    }

    @Test func goalIsMetAtExactlyTwenty() {
        #expect(!StreakCalculator.isGoalMet(activity("2026-10-30", cards: 19)))
        #expect(StreakCalculator.isGoalMet(activity("2026-10-30", cards: 10, quiz: 10)))
    }

    @Test func emptyHistoryHasNoStreak() {
        #expect(StreakCalculator.currentStreak(endingOn: date(2026, 10, 30), activity: [], calendar: chicago) == 0)
    }

    @Test func consecutiveMetDaysIncludingToday() {
        let rows = [
            activity("2026-10-28", cards: 20),
            activity("2026-10-29", quiz: 25),
            activity("2026-10-30", cards: 20),
        ]
        #expect(StreakCalculator.currentStreak(endingOn: date(2026, 10, 30), activity: rows, calendar: chicago) == 3)
    }

    /// Before studying today, the streak still shows yesterday's run.
    @Test func unmetTodayKeepsYesterdaysStreak() {
        let rows = [
            activity("2026-10-28", cards: 20),
            activity("2026-10-29", cards: 20),
            activity("2026-10-30", cards: 5),
        ]
        #expect(StreakCalculator.currentStreak(endingOn: date(2026, 10, 30, hour: 0), activity: rows, calendar: chicago) == 2)
    }

    @Test func aMissedDayBreaksTheStreak() {
        let rows = [
            activity("2026-10-26", cards: 20),
            activity("2026-10-27", cards: 20),
            // 10-28 missed
            activity("2026-10-29", cards: 20),
            activity("2026-10-30", cards: 20),
        ]
        #expect(StreakCalculator.currentStreak(endingOn: date(2026, 10, 30), activity: rows, calendar: chicago) == 2)
    }

    @Test func unmetDaysDoNotCount() {
        let rows = [activity("2026-10-29", cards: 19), activity("2026-10-30", cards: 3)]
        #expect(StreakCalculator.currentStreak(endingOn: date(2026, 10, 30), activity: rows, calendar: chicago) == 0)
    }

    /// US DST ends 2026-11-01 (a 25-hour day). Stepping by calendar day
    /// from noon must not skip or repeat a day.
    @Test func streakSpansTheDSTChange() {
        let rows = [
            activity("2026-10-31", cards: 20),
            activity("2026-11-01", cards: 20),
            activity("2026-11-02", cards: 20),
        ]
        #expect(StreakCalculator.currentStreak(endingOn: date(2026, 11, 2, hour: 23), activity: rows, calendar: chicago) == 3)
    }

    /// Day keys are local: 23:30 in Chicago is already the next day in UTC,
    /// but the streak follows the learner's calendar.
    @Test func usesTheCalendarsTimeZone() {
        let rows = [activity("2026-10-29", cards: 20), activity("2026-10-30", cards: 20)]
        let lateEvening = date(2026, 10, 30, hour: 23)
        #expect(StreakCalculator.currentStreak(endingOn: lateEvening, activity: rows, calendar: chicago) == 2)

        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // The same instant is 10-31 in Tokyo: today (10-31) unmet, so the
        // streak counts back from 10-30.
        #expect(StreakCalculator.currentStreak(endingOn: lateEvening, activity: rows, calendar: tokyo) == 2)
    }
}
