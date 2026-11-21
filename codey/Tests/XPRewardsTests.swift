import Foundation
import SwiftData
import Testing
@testable import codey

/// S41: the game layer's XP sources and the once-only rules that stop
/// farming. Every grant also lands in the leaderboard's weekly XP.
@MainActor
struct XPRewardsTests {
    private func store() -> WeeklyXPStore {
        WeeklyXPStore(defaults: UserDefaults(suiteName: "codey-xp-\(UUID().uuidString)")!)
    }

    @Test func grantAddsToTotalAndWeeklyXP() {
        let profile = UserProfile(username: "x")
        let weekly = store()
        XPRewards.grant(30, to: profile, weeklyXP: weekly, now: .now)
        #expect(profile.totalXP == 30)
        #expect(weekly.xp(now: .now) == 30)
    }

    @Test func grantIgnoresZeroAndNegative() {
        let profile = UserProfile(username: "x")
        let weekly = store()
        XPRewards.grant(0, to: profile, weeklyXP: weekly, now: .now)
        XPRewards.grant(-5, to: profile, weeklyXP: weekly, now: .now)
        #expect(profile.totalXP == 0)
        #expect(weekly.xp(now: .now) == 0)
    }

    @Test(arguments: [(0, 1, 5), (2, 3, 5), (3, 3, 0), (3, 1, 0)])
    func cardPaysOnlyWhenItMovesUp(previous: Int, new: Int, expected: Int) {
        #expect(XPRewards.forCard(previousScore: previous, newScore: new) == expected)
    }

    @Test func exercisePaysPerBlankOnce() {
        let profile = UserProfile(username: "x")
        let weekly = store()
        let first = XPRewards.payFirstSolve(id: "ex-1", amount: 30, profile: profile, weeklyXP: weekly, now: .now)
        let again = XPRewards.payFirstSolve(id: "ex-1", amount: 30, profile: profile, weeklyXP: weekly, now: .now)
        #expect(first == 30)
        #expect(again == 0)
        #expect(profile.totalXP == 30)
        #expect(profile.solvedExerciseIds == ["ex-1"])
    }

    @Test func dailyGoalBonusPaysOncePerDay() throws {
        let context = try TestSupport.inMemoryContext()
        let profile = UserProfile(username: "x")
        context.insert(profile)
        let now = Date.now
        let day = DailyActivity(day: DailyActivity.dayKey(for: now))
        day.quizAnswers = GatingConfig.standard.dailyGoal
        context.insert(day)
        try context.save()

        let weekly = store()
        #expect(try XPRewards.payQuestBonuses(context: context, profile: profile, weeklyXP: weekly, now: now) == [.dailyGoal])
        #expect(try XPRewards.payQuestBonuses(context: context, profile: profile, weeklyXP: weekly, now: now).isEmpty)
        #expect(profile.totalXP == XPRewards.dailyGoalBonus)
        #expect(profile.goalBonusDay == day.day)
    }

    @Test func noBonusBeforeTheGoalIsMet() throws {
        let context = try TestSupport.inMemoryContext()
        let profile = UserProfile(username: "x")
        context.insert(profile)
        let day = DailyActivity(day: DailyActivity.dayKey(for: .now))
        day.cardsRated = GatingConfig.standard.dailyGoal - 1
        context.insert(day)
        try context.save()

        #expect(try XPRewards.payQuestBonuses(context: context, profile: profile, weeklyXP: store(), now: .now).isEmpty)
        #expect(profile.totalXP == 0)
    }

    @Test func weeklyChallengeBonusPaysOncePerWeek() throws {
        let context = try TestSupport.inMemoryContext()
        _ = try TestSupport.insertTopic(context, id: "only-topic", easy: 1, medium: 0, hard: 0)
        let profile = UserProfile(username: "x")
        context.insert(profile)
        let now = Date.now
        for _ in 0..<WeeklyChallenge.goal {
            context.insert(QuizAnswerRecord(questionId: "q", topicId: "only-topic", correct: true, answeredAt: now))
        }
        try context.save()

        #expect(try WeeklyChallenge.isComplete(context: context, now: now))
        let weekly = store()
        #expect(try XPRewards.payQuestBonuses(context: context, profile: profile, weeklyXP: weekly, now: now) == [.weeklyChallenge])
        #expect(try XPRewards.payQuestBonuses(context: context, profile: profile, weeklyXP: weekly, now: now).isEmpty)
        #expect(profile.totalXP == XPRewards.weeklyChallengeBonus)
        #expect(profile.challengeBonusWeek == UTCWeek.key(for: now))
    }

    @Test func bonusesCarryTheirAmountAndTitle() {
        #expect(XPRewards.Bonus.dailyGoal.amount == 50)
        #expect(XPRewards.Bonus.weeklyChallenge.amount == 100)
        #expect(XPRewards.Bonus.dailyGoal.title == "Daily goal met")
    }
}
