import Foundation
import SwiftData
import Testing
@testable import codey

/// TC-22 … TC-31 end to end through QuizViewModel + SwiftData.
@MainActor
struct QuizViewModelTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeVM(
        _ topic: Topic,
        _ context: ModelContext,
        mode: QuizMode = .mixed,
        seed: UInt64 = 7,
        now: Date? = nil
    ) -> QuizViewModel {
        let date = now ?? t0
        return QuizViewModel(topic: topic, mode: mode, context: context, generator: SeededGenerator(seed: seed), now: { date })
    }

    private func profile(_ context: ModelContext) -> UserProfile { DataSeeder.ensureProfile(context: context) }

    /// Answers every question; `correct` decides per question.
    private func play(_ vm: QuizViewModel, correct: (Question) -> Bool = { _ in true }) {
        while let question = vm.currentQuestion, !vm.isFinished {
            vm.select(correct(question) ? question.correctOptionIndex : (question.correctOptionIndex + 1) % 4)
            vm.next()
        }
    }

    @Test func xpFollowsD5AndAWrongAnswerResetsTheStreak() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 12, medium: 0, hard: 0)
        let vm = makeVM(topic, context)

        var gains: [Int] = []
        for answerCorrectly in [true, true, true, false, true] {
            _ = try #require(vm.currentQuestion)
            vm.select(answerCorrectly ? 0 : 1)
            gains.append(vm.feedback?.gain?.amount ?? 0)
            vm.next()
        }
        #expect(gains == [10, 15, 20, 0, 10])
        #expect(vm.xpEarned == 55)
        #expect(profile(context).totalXP == 55)
        #expect(vm.bestStreak == 3)
        #expect(vm.streak == 1)
        #expect(vm.feedback == nil)
    }

    @Test func answerIsLockedOnceGiven() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 3, medium: 0, hard: 0)
        let vm = makeVM(topic, context)
        vm.select(1)
        vm.select(0)
        #expect(vm.feedback?.selectedIndex == 1)
        #expect(vm.results[0] == false)
    }

    @Test func percentageAndFinish() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 4, medium: 0, hard: 0)
        let vm = makeVM(topic, context)
        var n = 0
        play(vm) { _ in n += 1; return n != 2 }
        #expect(vm.isFinished)
        #expect(vm.correctCount == 3)
        #expect(vm.percentCorrect == 0.75)
    }

    @Test func detectsLevelUp() throws {
        let context = try TestSupport.inMemoryContext()
        profile(context).totalXP = 495
        let topic = try TestSupport.insertTopic(context, easy: 4, medium: 0, hard: 0)
        let vm = makeVM(topic, context)
        vm.select(0)
        #expect(vm.reachedLevel == 2)
        #expect(vm.levelUpToast == 2)
        vm.next()
        vm.select(0)
        #expect(vm.reachedLevel == 2, "no second level-up")
    }

    @Test func questionsRetireAfterThreeCorrectAcrossQuizzesAndLeaveThePool() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 4, medium: 4, hard: 0)
        for _ in 0..<2 { play(makeVM(topic, context)) }
        let third = makeVM(topic, context)
        play(third)
        #expect(third.newlyRetired == 4)

        let store = QuizProgressStore(context: context)
        let progress = try store.progressByQuestion(topicId: topic.id)
        #expect(progress.values.filter(\.isRetired).count == 4)

        // Medium unlocked (4/4 Easy retired); the next quiz is all Medium.
        #expect(third.unlockedTiers == [.medium])
        let next = makeVM(topic, context)
        #expect(next.questions.count == 4)
        #expect(next.questions.allSatisfy { $0.difficulty == .medium })
    }

    @Test func mediumUnlocksAtSeventyPercentAndStaysUnlocked() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 4, medium: 4, hard: 0)
        let store = QuizProgressStore(context: context)
        let easy = topic.questions.filter { $0.difficulty == .easy }.sorted { $0.id < $1.id }
        for question in easy.prefix(3) {
            for _ in 0..<3 { _ = try store.recordAnswer(question: question, correct: true, level: 1, at: t0) }
        }
        #expect(try store.unlockedTiers(topic: topic, level: 1) == [.easy, .medium])

        // A week later, reviews return the questions; Medium stays open.
        let vm = makeVM(topic, context, now: t0.addingTimeInterval(8 * 86_400))
        #expect(try store.progressByQuestion(topicId: topic.id).values.filter(\.isRetired).isEmpty)
        #expect(try store.unlockedTiers(topic: topic, level: 1) == [.easy, .medium])
        #expect(vm.reviewIDs.count == 3)
    }

    @Test func hardNeedsLevelThree() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 1, medium: 1, hard: 2)
        let store = QuizProgressStore(context: context)
        for question in topic.questions where question.difficulty != .hard {
            for _ in 0..<3 { _ = try store.recordAnswer(question: question, correct: true, level: 2, at: t0) }
        }
        #expect(try store.unlockedTiers(topic: topic, level: 2) == [.easy, .medium])
        #expect(makeVM(topic, context).questions.isEmpty, "Easy/Medium retired, Hard locked")

        profile(context).totalXP = 1_000 // level 3
        let vm = makeVM(topic, context)
        #expect(vm.questions.count == 2)
        #expect(vm.questions.allSatisfy { $0.difficulty == .hard })
        vm.select(0)
        #expect(try store.topicProgress(topicId: topic.id)?.hardUnlockedAt != nil, "unlock recorded on the next answer")
    }

    @Test func restrictedModeOnlyUsesTheChosenTier() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 4, medium: 4, hard: 0)
        let sticky = TopicProgress(topicId: topic.id)
        sticky.unlock([.medium], at: t0)
        context.insert(sticky)

        let vm = makeVM(topic, context, mode: .tier(.easy))
        #expect(vm.questions.count == 4)
        #expect(vm.questions.allSatisfy { $0.difficulty == .easy })
    }

    @Test func reviewPracticeGivesNoXPAndChangesNoProgress() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 2, medium: 0, hard: 0)
        for _ in 0..<3 { play(makeVM(topic, context)) }
        let xpBefore = profile(context).totalXP
        let recordsBefore = try context.fetchCount(FetchDescriptor<QuizAnswerRecord>())

        let review = makeVM(topic, context, mode: .review)
        #expect(review.questions.count == 2)
        #expect(review.isPractice)
        play(review) { _ in false }

        #expect(profile(context).totalXP == xpBefore)
        #expect(try context.fetchCount(FetchDescriptor<QuizAnswerRecord>()) == recordsBefore)
        let progress = try QuizProgressStore(context: context).progressByQuestion(topicId: topic.id)
        #expect(progress.values.allSatisfy { $0.isRetired }, "a wrong practice answer doesn't un-retire")
    }

    @Test func everyAnswerCountsTowardDailyActivity() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 3, medium: 0, hard: 0)
        play(makeVM(topic, context))
        #expect(try DailyActivity.forDay(t0, context: context).quizAnswers == 3)
    }

    @Test func accuracyUsesTheLastFiftyAnswers() throws {
        let context = try TestSupport.inMemoryContext()
        for n in 0..<60 {
            // 10 oldest wrong, then 50 right.
            context.insert(QuizAnswerRecord(questionId: "q", topicId: "t", correct: n >= 10, answeredAt: t0.addingTimeInterval(Double(n))))
        }
        #expect(try QuizProgressStore(context: context).accuracy(topicId: "t") == 1.0)
        #expect(try QuizProgressStore(context: context).accuracy(topicId: "other") == nil)
    }

    @Test func historyIsPrunedPerTopic() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 1, medium: 0, hard: 0)
        var config = GatingConfig()
        config.answerHistoryCap = 5
        let store = QuizProgressStore(context: context, config: config)
        let question = try #require(topic.questions.first)
        context.insert(QuizAnswerRecord(questionId: "x", topicId: "other", correct: true, answeredAt: t0))
        for n in 0..<8 {
            _ = try store.recordAnswer(question: question, correct: false, level: 1, at: t0.addingTimeInterval(Double(n)))
        }
        let topicID = topic.id
        let kept = try context.fetch(FetchDescriptor<QuizAnswerRecord>(predicate: #Predicate { $0.topicId == topicID }))
        #expect(kept.count == 5)
        #expect(kept.map(\.answeredAt).min() == t0.addingTimeInterval(3))
        #expect(try context.fetchCount(FetchDescriptor<QuizAnswerRecord>()) == 6, "other topics untouched")
    }

    @Test func restartBuildsAFreshQuiz() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 12, medium: 0, hard: 0)
        let vm = makeVM(topic, context)
        play(vm)
        #expect(vm.isFinished)
        vm.restart()
        #expect(!vm.isFinished)
        #expect(vm.index == 0 && vm.xpEarned == 0 && vm.streak == 0)
        #expect(vm.questions.count == 10)
    }

    @Test func emptyTopicIsFinishedImmediately() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 0, medium: 0, hard: 0)
        let vm = makeVM(topic, context)
        #expect(vm.questions.isEmpty)
        #expect(vm.isFinished)
    }

    @Test func bundledBankGivesANewLearnerOnlyEasyQuestions() throws {
        let context = try TestSupport.inMemoryContext()
        try DataSeeder.seed(context: context, bank: QuestionBankLoader.loadBank())
        for topic in try context.fetch(FetchDescriptor<Topic>()) {
            let vm = makeVM(topic, context)
            #expect(vm.questions.count == 8, "\(topic.id): only the 8 Easy questions are unlocked")
        }
    }
}
