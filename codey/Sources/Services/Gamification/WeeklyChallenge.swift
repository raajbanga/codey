import Foundation

/// Week math for FR-42/43: weeks start Monday 00:00 UTC, so everyone in a
/// group resets at the same moment.
enum UTCWeek {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Monday 00:00 UTC of `date`'s week.
    static func start(of date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    /// "yyyy-MM-dd" of the UTC Monday (weekly_xp.week_start).
    static func key(for date: Date) -> String {
        DailyActivity.dayKey(for: start(of: date), calendar: calendar)
    }

    /// ISO 8601 week number, 1–53.
    static func isoWeek(of date: Date) -> Int {
        calendar.component(.weekOfYear, from: date)
    }
}

/// FR-43 weekly challenge: 15 correct answers in one topic, rotating each
/// UTC week. Pure; progress comes from QuizAnswerRecord.
enum WeeklyChallenge {
    static let goal = 15

    struct Status: Equatable {
        let topicID: String
        let correct: Int

        var isComplete: Bool { correct >= WeeklyChallenge.goal }
        /// 0…1 for the progress bar.
        var progress: Double { min(Double(correct) / Double(WeeklyChallenge.goal), 1) }
    }

    /// topics[isoWeek % count], with topics sorted by id so every device
    /// picks the same one.
    static func topicID(for date: Date, topicIDs: [String]) -> String? {
        let sorted = topicIDs.sorted()
        guard !sorted.isEmpty else { return nil }
        return sorted[UTCWeek.isoWeek(of: date) % sorted.count]
    }

    /// Correct answers in this week's topic since Monday 00:00 UTC.
    static func status(now: Date, topicIDs: [String], answers: [(topicId: String, correct: Bool, answeredAt: Date)]) -> Status? {
        guard let topic = topicID(for: now, topicIDs: topicIDs) else { return nil }
        let start = UTCWeek.start(of: now)
        let correct = answers.lazy.filter { $0.topicId == topic && $0.correct && $0.answeredAt >= start }.count
        return Status(topicID: topic, correct: correct)
    }

    static func status(now: Date, topicIDs: [String], records: [QuizAnswerRecord]) -> Status? {
        status(now: now, topicIDs: topicIDs, answers: records.map { ($0.topicId, $0.correct, $0.answeredAt) })
    }
}
