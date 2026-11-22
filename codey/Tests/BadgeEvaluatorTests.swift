import Foundation
import SwiftData
import Testing
@testable import codey

/// FR-35: badge rules, awards, the XP they pay, and the trophy case's facts.
@MainActor
struct BadgeEvaluatorTests {

    @Test func rulesAtTheirThresholds() {
        #expect(BadgeEvaluator.qualifying(BadgeFacts()).isEmpty)
        #expect(BadgeEvaluator.qualifying(BadgeFacts([.userDecks: 1])) == [.firstDeck])
        #expect(BadgeEvaluator.qualifying(BadgeFacts([.streak: 6])).isEmpty)
        #expect(BadgeEvaluator.qualifying(BadgeFacts([.streak: 7])) == [.sevenDayStreak])
        #expect(BadgeEvaluator.qualifying(BadgeFacts([.streak: 30])) == [.sevenDayStreak, .streak30])
        #expect(BadgeEvaluator.qualifying(BadgeFacts([.totalXP: 999])).isEmpty)
        #expect(BadgeEvaluator.qualifying(BadgeFacts([.totalXP: 1_000])) == [.xp1000])
        #expect(BadgeEvaluator.qualifying(BadgeFacts([.weeklyChallenges: 1])) == [.weeklyChallenge])
        #expect(BadgeEvaluator.qualifying(BadgeFacts([.level: 5])) == [.level2, .level5])
        #expect(BadgeEvaluator.qualifying(BadgeFacts([.decksMastered: 4])) == [.deck1])
        #expect(BadgeEvaluator.qualifying(BadgeFacts([.cardsMastered: 50])) == [.cards20, .cards50])
        #expect(BadgeEvaluator.qualifying(BadgeFacts([.drills: 5, .challenges: 1])) == [.drill1, .drills5, .challenge1])
        #expect(BadgeEvaluator.qualifying(BadgeFacts([.correctAnswers: 250, .hardTiers: 1, .topicsCompleted: 1]))
            == [.correct50, .correct250, .hardTier, .topic1])
    }

    /// Every badge has words for both states and pays more the harder it is
    /// within its metric.
    @Test func catalogIsConsistent() {
        for badge in Badge.allCases {
            #expect(!badge.requirement.isEmpty && !badge.title.isEmpty)
            #expect((1...3).contains(badge.rings))
        }
        let byMetric = Dictionary(grouping: Badge.allCases, by: \.metric)
        for badges in byMetric.values {
            let sorted = badges.sorted { $0.target < $1.target }
            #expect(sorted.map(\.xp) == sorted.map(\.xp).sorted())
        }
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
        #expect(facts[.totalXP] == 1_200)
        #expect(facts[.level] == 3)
        #expect(facts[.streak] == 7)
        #expect(facts[.dailyGoals] == 7)
        #expect(try BadgeEvaluator.award(context: context, now: now) == [.level2, .xp1000, .sevenDayStreak])
    }

    @Test func factsGatherOnlyWhatTheBadgesNeed() throws {
        let context = try TestSupport.inMemoryContext()
        context.insert(UserProfile(username: "L", totalXP: 1_200))
        try context.save()

        let xpOnly = try BadgeEvaluator.facts(in: context, for: [.xp1000])
        #expect(xpOnly == BadgeFacts([.totalXP: 1_200]))
    }

    /// Each badge pays its XP once, and badge XP that reaches a level
    /// earns that level's badge in the same call.
    @Test func awardsPayXPAndCascade() throws {
        let context = try TestSupport.inMemoryContext()
        let profile = UserProfile(username: "L", totalXP: 1_990)
        context.insert(profile)
        try context.save()

        // Level 4: Level 2 (+25) and 1,000 XP (+50) reach 2,065 = Level 5 (+75).
        #expect(try BadgeEvaluator.award(context: context) == [.level2, .xp1000, .level5])
        #expect(profile.totalXP == 1_990 + 25 + 50 + 75)
        #expect(try BadgeEvaluator.award(context: context).isEmpty)
        #expect(profile.totalXP == 2_140)
    }

    @Test func drillsAndChallengesCountSeparately() throws {
        let context = try TestSupport.inMemoryContext()
        let profile = UserProfile(username: "L", totalXP: 0)
        profile.solvedExerciseIds = ["ex-1", "ex-2", "ch-two-sum"]
        context.insert(profile)
        try context.save()

        let facts = try BadgeEvaluator.facts(in: context)
        #expect(facts[.drills] == 2)
        #expect(facts[.challenges] == 1)
    }

    @Test func masteredCardsAndDecksCount() throws {
        let context = try TestSupport.inMemoryContext()
        let full = try TestSupport.insertDeck(context, title: "Full", prompts: ["a", "b"])
        let half = try TestSupport.insertDeck(context, title: "Half", origin: .starter, prompts: ["c", "d"])
        for card in full.cards { card.applyRemoteProgress(score: Flashcard.maxMastery, lastReviewedAt: .now, retiredAt: nil) }
        half.cards.first?.applyRemoteProgress(score: Flashcard.maxMastery, lastReviewedAt: .now, retiredAt: .now)
        try context.save()

        let facts = try BadgeEvaluator.facts(in: context)
        #expect(facts[.cardsMastered] == 3)
        #expect(facts[.decksMastered] == 1)
    }

    @Test func aTopicIsCompleteWhenEveryQuestionIsRetired() throws {
        let context = try TestSupport.inMemoryContext()
        try TestSupport.insertTopic(context, id: "topic-a", easy: 2, medium: 0, hard: 0)
        try TestSupport.insertTopic(context, id: "topic-b", easy: 2, medium: 0, hard: 0)
        for (id, topic) in [("topic-a-e1", "topic-a"), ("topic-a-e2", "topic-a"), ("topic-b-e1", "topic-b")] {
            let progress = QuestionProgress(questionId: id, topicId: topic, difficulty: .easy)
            progress.retiredAt = .now
            progress.totalCorrect = 3
            context.insert(progress)
        }
        let tier = TopicProgress(topicId: "topic-a")
        tier.hardUnlockedAt = .now
        context.insert(tier)
        try context.save()

        let facts = try BadgeEvaluator.facts(in: context)
        #expect(facts[.topicsCompleted] == 1)
        #expect(facts[.correctAnswers] == 9)
        #expect(facts[.hardTiers] == 1)
    }

    @Test func nothingLeftToEarnAwardsNothing() throws {
        let context = try TestSupport.inMemoryContext()
        context.insert(UserProfile(username: "L", totalXP: 5_000))
        for badge in Badge.allCases {
            context.insert(BadgeAward(badge: badge, earnedAt: .now))
        }
        try context.save()
        #expect(try BadgeEvaluator.award(context: context).isEmpty)
    }

    /// The hook: a quiz answer that crosses 1,000 XP awards the badges.
    @Test func quizAnswerCrossingTheXPTargetAwardsTheBadge() throws {
        let context = try TestSupport.inMemoryContext()
        try DataSeeder.seed(context: context, bank: QuestionBankLoader.loadBank())
        DataSeeder.ensureProfile(context: context).totalXP = 995
        try context.save()
        let topic = try #require(try context.fetch(FetchDescriptor<Topic>()).first)
        let quiz = QuizViewModel(topic: topic, mode: .mixed, context: context)

        quiz.select(try #require(quiz.currentQuestion).correctOptionIndex)

        let badges = try context.fetch(FetchDescriptor<BadgeAward>()).compactMap(\.badge)
        #expect(Set(badges) == [.level2, .xp1000])
    }

    /// Play's "Next badges": closest to done first, earned ones left out.
    @Test func nextBadgesSortByProgress() {
        let facts = BadgeFacts([.decksMastered: 4, .cardsMastered: 10, .level: 1])
        let next = HomeLogic.nextBadges(earned: [.deck1], facts: facts)
        // Level 1 of 2 ties Master 20 Cards at half; the smaller reward goes first.
        #expect(next == [.decks5, .level2, .cards20])
    }
}
