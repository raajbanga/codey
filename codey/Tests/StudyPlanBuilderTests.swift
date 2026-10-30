import Foundation
import Testing
@testable import codey

/// FR-38 weekly study plan.
struct StudyPlanBuilderTests {
    private let topics = ["algorithms", "data-structures", "databases", "networking", "oop"]

    @Test func notStartedTopicsComeFirstThenLowestAccuracy() {
        let plan = StudyPlanBuilder.build(
            topicIDs: topics,
            answerCounts: ["algorithms": 20, "data-structures": 20, "databases": 4, "networking": 20, "oop": 20],
            accuracy: ["algorithms": 0.9, "data-structures": 0.4, "databases": 0.1, "networking": 0.6, "oop": 0.5]
        )
        // databases has < 5 answers: "not started", ranked first even with 10%.
        #expect(plan.map(\.topicID) == ["databases", "data-structures", "oop"])
        #expect(plan[0].isNotStarted)
        #expect(plan[1].accuracy == 0.4)
    }

    @Test func tiesKeepTopicOrder() {
        let plan = StudyPlanBuilder.build(
            topicIDs: topics,
            answerCounts: Dictionary(uniqueKeysWithValues: topics.map { ($0, 10) }),
            accuracy: Dictionary(uniqueKeysWithValues: topics.map { ($0, 0.5) })
        )
        #expect(plan.map(\.topicID) == ["algorithms", "data-structures", "databases"])
    }

    @Test func sparseDataPicksTheFirstUnstartedTopics() {
        let plan = StudyPlanBuilder.build(topicIDs: topics, answerCounts: [:], accuracy: [:])
        #expect(plan.map(\.topicID) == ["algorithms", "data-structures", "databases"])
        #expect(plan.allSatisfy { $0.isNotStarted })
        #expect(StudyPlanBuilder.build(topicIDs: ["a"], answerCounts: [:], accuracy: [:]).count == 1)
        #expect(StudyPlanBuilder.build(topicIDs: [], answerCounts: [:], accuracy: [:]).isEmpty)
    }

    @Test func exactlyFiveAnswersCountsAsStarted() {
        let plan = StudyPlanBuilder.build(topicIDs: ["a", "b"], answerCounts: ["a": 5, "b": 4], accuracy: ["a": 0.2, "b": 0])
        #expect(plan.map(\.topicID) == ["b", "a"])
        #expect(plan[1].accuracy == 0.2)
    }

    // MARK: Week rollover

    private var chicago: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
        chicago.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test func weeksStartOnMonday() {
        // 2026-10-26 is a Monday; Sunday 11-01 is still that week.
        #expect(StudyPlanBuilder.weekStart(for: date(10, 26, hour: 0), calendar: chicago) == "2026-10-26")
        #expect(StudyPlanBuilder.weekStart(for: date(11, 1, hour: 23), calendar: chicago) == "2026-10-26")
        #expect(StudyPlanBuilder.weekStart(for: date(11, 2, hour: 0), calendar: chicago) == "2026-11-02")
    }

    @Test func cachedPlanHoldsForTheWeekAndRebuildsOnMonday() {
        var builds = 0
        let build: () -> [StudyPlanBuilder.Entry] = {
            builds += 1
            return [StudyPlanBuilder.Entry(topicID: builds == 1 ? "a" : "b", accuracy: nil)]
        }
        let known: Set = ["a", "b"]

        let first = StudyPlan.current(cached: nil, now: date(10, 27), knownTopicIDs: known, calendar: chicago, build: build)
        let midweek = StudyPlan.current(cached: first, now: date(10, 31), knownTopicIDs: known, calendar: chicago, build: build)
        #expect(midweek == first)
        #expect(builds == 1)

        let nextWeek = StudyPlan.current(cached: first, now: date(11, 2), knownTopicIDs: known, calendar: chicago, build: build)
        #expect(nextWeek.weekStart == "2026-11-02")
        #expect(nextWeek.topicIDs == ["b"])
    }

    @Test func cachedPlanRebuildsIfATopicDisappears() {
        let cached = StudyPlan(weekStart: "2026-10-26", topicIDs: ["gone"])
        let plan = StudyPlan.current(cached: cached, now: date(10, 28), knownTopicIDs: ["a"], calendar: chicago) {
            [StudyPlanBuilder.Entry(topicID: "a", accuracy: nil)]
        }
        #expect(plan.topicIDs == ["a"])
    }
}
