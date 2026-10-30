import Foundation
import SwiftData
import Testing
@testable import codey

/// FR-35: badge rules and awards.
@MainActor
struct BadgeEvaluatorTests {

    @Test func rulesAtTheirThresholds() {
        #expect(BadgeEvaluator.qualifying(BadgeFacts()).isEmpty)
        #expect(BadgeEvaluator.qualifying(BadgeFacts(userDeckCount: 1)) == [.firstDeck])
        #expect(BadgeEvaluator.qualifying(BadgeFacts(streak: 6)).isEmpty)
        #expect(BadgeEvaluator.qualifying(BadgeFacts(streak: 7)) == [.sevenDayStreak])
        #expect(BadgeEvaluator.qualifying(BadgeFacts(totalXP: 999)).isEmpty)
        #expect(BadgeEvaluator.qualifying(BadgeFacts(totalXP: 1_000)) == [.xp1000])
        #expect(BadgeEvaluator.qualifying(BadgeFacts(weeklyChallengesCompleted: 1)) == [.weeklyChallenge])
    }

    @Test func starterAndDeletedDecksDontEarnFirstDeck() throws {
        let context = try TestSupport.inMemoryContext()
        try TestSupport.insertDeck(context, origin: .starter)
        let deleted = try TestSupport.insertDeck(context, title: "Gone")
        deleted.deletedAt = .now
        try context.save()

        #expect(try BadgeEvaluator.award(context: context).isEmpty)
    }

    @Test func awardsOnceAndKeepsTheBadgeAfterTheDeckIsGone() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertDeck(context)
        try context.save()

        #expect(try BadgeEvaluator.award(context: context) == [.firstDeck])
        try context.save()
        // Second evaluation: already earned, nothing new.
        #expect(try BadgeEvaluator.award(context: context).isEmpty)

        deck.deletedAt = .now
        try context.save()
        #expect(try BadgeEvaluator.award(context: context).isEmpty)
        #expect(try context.fetch(FetchDescriptor<BadgeAward>()).compactMap(\.badge) == [.firstDeck])
    }

    @Test func factsReadXPAndTheDerivedStreak() throws {
        let context = try TestSupport.inMemoryContext()
        context.insert(UserProfile(username: "L", totalXP: 1_200))
        let now = Date.now
        for offset in 0..<7 {
            let date = try #require(Calendar.current.date(byAdding: .day, value: -offset, to: now))
            let row = DailyActivity(day: DailyActivity.dayKey(for: date))
            row.quizAnswers = 20
            context.insert(row)
        }
        try context.save()

        let facts = try BadgeEvaluator.facts(in: context, now: now)
        #expect(facts.totalXP == 1_200)
        #expect(facts.streak == 7)
        #expect(try BadgeEvaluator.award(context: context, now: now) == [.sevenDayStreak, .xp1000])
    }

    /// The hook: a quiz answer that crosses 1,000 XP awards the badge.
    @Test func quizAnswerCrossingTheXPTargetAwardsTheBadge() throws {
        let context = try TestSupport.inMemoryContext()
        try DataSeeder.seed(context: context, bank: QuestionBankLoader.loadBank())
        DataSeeder.ensureProfile(context: context).totalXP = 995
        try context.save()
        let topic = try #require(try context.fetch(FetchDescriptor<Topic>()).first)
        let quiz = QuizViewModel(topic: topic, mode: .mixed, context: context)

        quiz.select(try #require(quiz.currentQuestion).correctOptionIndex)

        #expect(try context.fetch(FetchDescriptor<BadgeAward>()).compactMap(\.badge) == [.xp1000])
    }
}
