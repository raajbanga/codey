import Foundation
import Observation
import SwiftData
import os

/// One quiz run (FR-19/20, FR-22–30, D5). Builds the question set from the
/// topic's pool, grades answers, awards XP, records progress, and reports
/// level-ups and tier unlocks.
@MainActor
@Observable
final class QuizViewModel {
    /// What one answer did, for the UI.
    struct AnswerFeedback: Equatable {
        let selectedIndex: Int
        let correct: Bool
        /// nil when no XP was awarded (wrong, or review practice).
        let gain: XPGain?
        let retiredQuestion: Bool
    }

    let topic: Topic
    let mode: QuizMode

    private(set) var questions: [Question] = []
    private(set) var index = 0
    /// Per question: nil = not answered yet.
    private(set) var results: [Bool?] = []
    private(set) var feedback: AnswerFeedback?
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var xpEarned = 0
    private(set) var newlyRetired = 0
    private(set) var unlockedTiers: [Difficulty] = []
    /// Highest new level reached during this quiz, if any.
    private(set) var reachedLevel: Int?
    /// Latest level-up, for the in-quiz toast (cleared by the view).
    var levelUpToast: Int?
    /// Latest quest bonus paid (S41), for the in-quiz toast (cleared by the view).
    var bonusToast: XPRewards.Bonus?
    private(set) var isFinished = false
    /// Questions in this set that came back from retirement (FR-28).
    private(set) var reviewIDs: Set<String> = []

    private let context: ModelContext
    private let store: QuizProgressStore
    private let now: () -> Date
    private let weeklyXP: WeeklyXPStore
    private var generator: AnyRandomGenerator
    @ObservationIgnored private var cachedProfile: UserProfile?

    init(
        topic: Topic,
        mode: QuizMode,
        context: ModelContext,
        config: GatingConfig = .standard,
        generator: any RandomNumberGenerator = SystemRandomNumberGenerator(),
        weeklyXP: WeeklyXPStore = WeeklyXPStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.topic = topic
        self.mode = mode
        self.context = context
        self.store = QuizProgressStore(context: context, config: config)
        self.now = now
        self.weeklyXP = weeklyXP
        self.generator = AnyRandomGenerator(generator)
        start()
    }

    // MARK: State

    var currentQuestion: Question? { index < questions.count ? questions[index] : nil }
    var hasAnswered: Bool { feedback != nil }
    var correctCount: Int { results.filter { $0 == true }.count }
    var isPractice: Bool { mode == .review }
    /// FR-20.
    var percentCorrect: Double { questions.isEmpty ? 0 : Double(correctCount) / Double(questions.count) }
    var isLastQuestion: Bool { index + 1 >= questions.count }

    // MARK: Actions

    /// Grades the selected option. Ignored once the question is answered.
    func select(_ optionIndex: Int) {
        guard feedback == nil, let question = currentQuestion else { return }
        let correct = optionIndex == question.correctOptionIndex
        let timestamp = now()
        results[index] = correct

        var gain: XPGain?
        if correct {
            streak += 1
            bestStreak = max(bestStreak, streak)
        } else {
            streak = 0
        }

        var retired = false
        if !isPractice {
            let levelBefore = profile.level
            if correct {
                let amount = XPPolicy.xpForCorrectAnswer(tier: question.difficulty, streakAfterIncrement: streak)
                XPRewards.grant(amount, to: profile, weeklyXP: weeklyXP, now: timestamp)
                xpEarned += amount
                gain = XPGain(amount: amount, breakdown: XPPolicy.breakdown(tier: question.difficulty, streakAfterIncrement: streak))
            }
            let levelAfter = profile.level
            if levelAfter > levelBefore {
                reachedLevel = levelAfter
                levelUpToast = levelAfter
            }
            do {
                let result = try store.recordAnswer(question: question, correct: correct, level: levelAfter, at: timestamp)
                retired = result.retired
                if retired { newlyRetired += 1 }
                unlockedTiers += result.unlocked.filter { !unlockedTiers.contains($0) }
            } catch {
                Logger.quiz.error("Recording an answer failed: \(String(describing: error))")
            }
        }

        do {
            try DailyActivity.forDay(timestamp, context: context).quizAnswers += 1
            // Quest bonuses (S41) before badges, so their XP counts toward xp1000.
            let bonuses = try XPRewards.payQuestBonuses(context: context, profile: profile, weeklyXP: weeklyXP, now: timestamp)
            if !bonuses.isEmpty {
                xpEarned += bonuses.map(\.amount).reduce(0, +)
                bonusToast = bonuses.last
            }
            // XP, the daily goal, and the weekly challenge move here → badges (FR-35).
            try BadgeEvaluator.award(context: context, now: timestamp)
            try context.save()
        } catch {
            // B11: never swallow silently.
            Logger.quiz.error("Saving a quiz answer failed: \(String(describing: error))")
        }

        feedback = AnswerFeedback(selectedIndex: optionIndex, correct: correct, gain: gain, retiredQuestion: retired)
    }

    func next() {
        guard feedback != nil else { return }
        if isLastQuestion {
            isFinished = true
        } else {
            index += 1
            feedback = nil
        }
    }

    /// "Quiz again": a new set with the same mode.
    func restart() {
        start()
    }

    // MARK: Private

    private func start() {
        do {
            questions = try store.buildQuiz(topic: topic, mode: mode, level: profile.level, now: now(), using: &generator)
            let progress = try store.progressByQuestion(topicId: topic.id)
            reviewIDs = Set(questions.map(\.id).filter { progress[$0]?.isReview == true })
            if context.hasChanges { try context.save() } // review returns
        } catch {
            Logger.quiz.error("Building a quiz failed: \(String(describing: error))")
            questions = []
            reviewIDs = []
        }
        index = 0
        results = Array(repeating: nil, count: questions.count)
        feedback = nil
        streak = 0
        bestStreak = 0
        xpEarned = 0
        newlyRetired = 0
        unlockedTiers = []
        reachedLevel = nil
        levelUpToast = nil
        isFinished = questions.isEmpty
    }

    /// Fetched once; fetched again only if the row went away (sign-out wipe).
    private var profile: UserProfile {
        if let cachedProfile, cachedProfile.modelContext != nil, !cachedProfile.isDeleted { return cachedProfile }
        let profile = DataSeeder.ensureProfile(context: context)
        cachedProfile = profile
        return profile
    }
}
