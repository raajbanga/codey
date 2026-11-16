import Foundation
import SwiftData
import Testing
@testable import codey

/// FR-61 (S43): quiz history, daily activity, badges and solved exercises
/// sync, so quests, streak, accuracy and badges match on every device.
@MainActor
struct ProgressHistorySyncTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func fetch<T: PersistentModel>(_ type: T.Type, _ h: SyncHarness) throws -> [T] {
        try h.context.fetch(FetchDescriptor<T>())
    }

    // MARK: Quiz answers

    @Test func answersArePushedOnceAndPulledWithoutDuplicates() async throws {
        let h = try SyncHarness()
        h.context.insert(QuizAnswerRecord(questionId: "q-1", topicId: "topic-swift", correct: true, answeredAt: t0))
        try h.context.save()
        #expect(await h.engine.syncNow())
        #expect(h.remote.quizAnswers.count == 1)

        // Another device answered twice; one of its rows repeats ours.
        h.remote.otherDeviceUpsert(progress: ProgressBatch(answers: [
            QuizAnswerPayload(questionId: "q-1", topicId: "topic-swift", correct: true, answeredAt: t0),
            QuizAnswerPayload(questionId: "q-2", topicId: "topic-swift", correct: false, answeredAt: t0.addingTimeInterval(60)),
        ]))
        #expect(await h.engine.syncNow())
        let records = try fetch(QuizAnswerRecord.self, h)
        #expect(records.count == 2)
        #expect(Set(records.map(\.questionId)) == ["q-1", "q-2"])
        #expect(h.remote.quizAnswers.count == 2, "the pulled answer isn't stored twice")
    }

    @Test func theFirstSyncAfterTheUpdateBackfillsOldHistory() throws {
        let h = try SyncHarness()
        h.context.insert(QuizAnswerRecord(questionId: "q-1", topicId: "topic-swift", correct: true, answeredAt: t0))
        h.context.insert(BadgeAward(badge: .firstDeck, earnedAt: t0))
        try h.context.save()
        let sync = ProgressSync(context: h.context)
        let lastProgressPush = t0.addingTimeInterval(3600)

        let incremental = try sync.localChanges(since: lastProgressPush)
        #expect(incremental.answers.isEmpty && incremental.badges.isEmpty)

        let backfill = try sync.localChanges(since: lastProgressPush, historySince: .some(nil))
        #expect(backfill.answers.count == 1 && backfill.badges.count == 1)
    }

    @Test func aPulledAnswerWithinAMillisecondIsTheSameAnswer() async throws {
        let h = try SyncHarness()
        h.context.insert(QuizAnswerRecord(questionId: "q-1", topicId: "topic-swift", correct: true, answeredAt: t0))
        try h.context.save()
        try ProgressSync(context: h.context).apply(ProgressBatch(answers: [
            QuizAnswerPayload(questionId: "q-1", topicId: "topic-swift", correct: true, answeredAt: t0.addingTimeInterval(0.0004)),
        ]))
        #expect(try fetch(QuizAnswerRecord.self, h).count == 1)
    }

    // MARK: Daily activity

    @Test func ownDaysArePushedUnderThisDevice() async throws {
        let h = try SyncHarness()
        let today = try DailyActivity.forDay(.now, context: h.context)
        today.quizAnswers = 8
        today.cardsRated = 4
        try h.context.save()
        #expect(await h.engine.syncNow())
        let row = try #require(h.remote.dailyActivity.values.first)
        #expect(row.deviceId == "test-device")
        #expect(row.day == today.day)
        #expect(row.quizAnswers == 8 && row.cardsRated == 4)
    }

    @Test func otherDevicesAddUpToTheDailyGoal() async throws {
        let h = try SyncHarness()
        let day = DailyActivity.dayKey(for: .now)
        let mine = try DailyActivity.forDay(.now, context: h.context)
        mine.quizAnswers = 12
        try h.context.save()
        h.remote.otherDeviceUpsert(progress: ProgressBatch(days: [
            DailyActivityPayload(deviceId: "phone", day: day, cardsRated: 2, quizAnswers: 6),
        ]))
        #expect(await h.engine.syncNow())

        let totals = try StreakCalculator.dayTotals(for: [day], context: h.context)
        #expect(totals[day] == 20)
        #expect(try fetch(DeviceDayActivity.self, h).count == 1)
        #expect(mine.quizAnswers == 12, "another device's count doesn't land in this device's row")
    }

    @Test func thisDevicesOwnRowsComeBackAfterAReinstall() throws {
        let h = try SyncHarness()
        try ProgressSync(context: h.context, deviceId: "test-device").apply(ProgressBatch(days: [
            DailyActivityPayload(deviceId: "test-device", day: "2026-11-14", cardsRated: 3, quizAnswers: 17),
        ]))
        let day = try #require(try fetch(DailyActivity.self, h).first)
        #expect(day.day == "2026-11-14" && day.quizAnswers == 17 && day.cardsRated == 3)
        #expect(try fetch(DeviceDayActivity.self, h).isEmpty)
    }

    @Test func dayCountersKeepTheLarger() throws {
        let h = try SyncHarness()
        let sync = ProgressSync(context: h.context, deviceId: "me")
        try sync.apply(ProgressBatch(days: [DailyActivityPayload(deviceId: "phone", day: "2026-11-14", cardsRated: 5, quizAnswers: 9)]))
        try sync.apply(ProgressBatch(days: [DailyActivityPayload(deviceId: "phone", day: "2026-11-14", cardsRated: 2, quizAnswers: 11)]))
        let row = try #require(try fetch(DeviceDayActivity.self, h).first)
        #expect(row.cardsRated == 5 && row.quizAnswers == 11)
    }

    @Test func streakCountsDaysMetOnAnyDevice() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12))!
        let totals = ["2026-11-15": 20, "2026-11-14": 25, "2026-11-13": 19]
        #expect(StreakCalculator.currentStreak(endingOn: today, totals: totals, calendar: calendar) == 2)
    }

    // MARK: Badges

    @Test func badgesArePushedAndPulledKeepingTheEarliestDate() async throws {
        let h = try SyncHarness()
        h.context.insert(BadgeAward(badge: .firstDeck, earnedAt: t0.addingTimeInterval(100)))
        try h.context.save()
        #expect(await h.engine.syncNow())
        #expect(h.remote.badgeAwards["firstDeck"] != nil)

        h.remote.otherDeviceUpsert(progress: ProgressBatch(badges: [
            BadgeAwardPayload(badge: "firstDeck", earnedAt: t0),
            BadgeAwardPayload(badge: "xp1000", earnedAt: t0),
        ]))
        #expect(await h.engine.syncNow())
        let awards = try fetch(BadgeAward.self, h).keyed(by: \.badgeRaw)
        #expect(awards["firstDeck"]?.earnedAt == t0)
        #expect(awards["xp1000"]?.earnedAt == t0)
    }

    @Test func unknownBadgesAreIgnored() throws {
        let h = try SyncHarness()
        try ProgressSync(context: h.context).apply(ProgressBatch(badges: [BadgeAwardPayload(badge: "future", earnedAt: t0)]))
        #expect(try fetch(BadgeAward.self, h).isEmpty)
    }

    // MARK: Solved exercises

    @Test func solvedExercisesMergeAsAUnion() async throws {
        let h = try SyncHarness()
        let profile = DataSeeder.ensureProfile(context: h.context)
        profile.solvedExerciseIds = ["ex-a"]
        try h.context.save()
        h.remote.profile = ProfilePayload(displayName: "Remote Name", avatarId: nil, totalXP: 0, solvedExerciseIds: ["ex-b"])

        #expect(await h.engine.syncNow())
        #expect(profile.solvedExerciseIds == ["ex-a", "ex-b"])
        #expect(Set(h.remote.profile?.solvedExerciseIds ?? []) == ["ex-a", "ex-b"])
    }
}
