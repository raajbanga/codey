import Foundation

/// FR-38 weekly study plan: the three topics that need the most work.
/// Pure (unit-tested); StudyPlan caches one result per week so the plan
/// doesn't reshuffle while the learner works through it.
enum StudyPlanBuilder {
    static let size = 3
    /// Fewer answers than this and accuracy isn't meaningful yet: the
    /// topic counts as "not started" and is ranked first.
    static let minimumAnswers = 5

    struct Entry: Equatable {
        let topicID: String
        /// FR-36 accuracy over the last `accuracyWindow` answers; nil when
        /// the topic isn't started.
        let accuracy: Double?

        var isNotStarted: Bool { accuracy == nil }
    }

    /// Not-started topics first, then lowest accuracy. Ties keep `topicIDs`
    /// order, so the result is stable.
    ///
    /// - Parameters:
    ///   - topicIDs: every topic, in display order.
    ///   - answerCounts: answers in the accuracy window, per topic.
    ///   - accuracy: accuracy in the window, per topic.
    static func build(topicIDs: [String], answerCounts: [String: Int], accuracy: [String: Double]) -> [Entry] {
        let entries = topicIDs.enumerated().map { index, id in
            let started = (answerCounts[id] ?? 0) >= minimumAnswers
            return (index, Entry(topicID: id, accuracy: started ? accuracy[id] ?? 0 : nil))
        }
        return entries
            .sorted { lhs, rhs in
                switch (lhs.1.accuracy, rhs.1.accuracy) {
                case (nil, nil): lhs.0 < rhs.0
                case (nil, _): true
                case (_, nil): false
                case let (l?, r?): l == r ? lhs.0 < rhs.0 : l < r
                }
            }
            .prefix(size)
            .map(\.1)
    }

    /// Monday of `date`'s week, as a DailyActivity day key ("yyyy-MM-dd").
    static func weekStart(for date: Date, calendar: Calendar = .current) -> String {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        let start = mondayFirst.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return DailyActivity.dayKey(for: start, calendar: calendar)
    }
}

/// One week's plan, as cached in @AppStorage (JSON). Only the picked
/// topics are cached; rows show live accuracy.
struct StudyPlan: Codable, Equatable {
    var weekStart: String
    var topicIDs: [String]

    /// Reuses `cached` while it's for the current week and its topics still
    /// exist; otherwise builds a new plan with `build`.
    static func current(
        cached: StudyPlan?,
        now: Date,
        knownTopicIDs: Set<String>,
        calendar: Calendar = .current,
        build: () -> [StudyPlanBuilder.Entry]
    ) -> StudyPlan {
        let week = StudyPlanBuilder.weekStart(for: now, calendar: calendar)
        if let cached, cached.weekStart == week, !cached.topicIDs.isEmpty,
           cached.topicIDs.allSatisfy(knownTopicIDs.contains) {
            return cached
        }
        return StudyPlan(weekStart: week, topicIDs: build().map(\.topicID))
    }
}
