import Foundation
import SwiftData
import os

/// Quiz progress on top of SwiftData: retirement, review return, sticky
/// unlocks, the answer history, and quiz building (FR-19, FR-22–29, FR-36).
/// The rules themselves are pure (QuestionProgress, TierGate, QuestionPool);
/// this type only fetches, applies, and inserts. It never saves.
@MainActor
struct QuizProgressStore {
    let context: ModelContext
    var config: GatingConfig = .standard

    struct AnswerResult: Equatable {
        /// This answer retired the question.
        var retired: Bool
        /// Tiers this answer unlocked for the topic, Easy → Hard.
        var unlocked: [Difficulty]
    }

    // MARK: Reads

    func progressByQuestion(topicId: String) throws -> [String: QuestionProgress] {
        let rows = try context.fetch(FetchDescriptor<QuestionProgress>(predicate: #Predicate { $0.topicId == topicId }))
        return Dictionary(rows.map { ($0.questionId, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func topicProgress(topicId: String) throws -> TopicProgress? {
        var descriptor = FetchDescriptor<TopicProgress>(predicate: #Predicate { $0.topicId == topicId })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Sticky ∪ currently earned tiers.
    func unlockedTiers(topic: Topic, level: Int) throws -> Set<Difficulty> {
        TierGate.unlockedTiers(
            tallies: Self.tallies(questions: topic.questions, progress: try progressByQuestion(topicId: topic.id)),
            level: level,
            alreadyUnlocked: try topicProgress(topicId: topic.id)?.unlockedTiers ?? [],
            config: config
        )
    }

    func accuracy(topicId: String) throws -> Double? {
        var descriptor = FetchDescriptor<QuizAnswerRecord>(
            predicate: #Predicate { $0.topicId == topicId },
            sortBy: [SortDescriptor(\.answeredAt, order: .reverse)]
        )
        descriptor.fetchLimit = config.accuracyWindow
        return Self.accuracy(of: try context.fetch(descriptor), window: config.accuracyWindow)
    }

    // MARK: Quiz building

    /// Returns due reviews to the pool (FR-28), then picks the questions.
    func buildQuiz<G: RandomNumberGenerator>(
        topic: Topic,
        mode: QuizMode,
        level: Int,
        now: Date,
        using generator: inout G
    ) throws -> [Question] {
        let progress = try progressByQuestion(topicId: topic.id)
        if mode != .review {
            for row in progress.values { row.returnForReviewIfDue(now: now, config: config) }
        }
        let unlocked = try unlockedTiers(topic: topic, level: level)
        let ids = QuestionPool.build(
            from: Self.candidates(questions: topic.questions, progress: progress),
            unlocked: unlocked,
            mode: mode,
            size: config.quizSize,
            config: config,
            using: &generator
        )
        let byID = Dictionary(topic.questions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    // MARK: Writes

    /// Grades one answer: question progress (FR-23/24/28), the answer
    /// history (FR-36), and sticky unlocks (FR-25/26) at `level` (the level
    /// AFTER this answer's XP).
    func recordAnswer(question: Question, correct: Bool, level: Int, at date: Date) throws -> AnswerResult {
        guard let topic = question.topic else { return AnswerResult(retired: false, unlocked: []) }

        var progress = try progressByQuestion(topicId: topic.id)
        let row: QuestionProgress
        if let existing = progress[question.id] {
            row = existing
        } else {
            row = QuestionProgress(questionId: question.id, topicId: topic.id, difficulty: question.difficulty)
            context.insert(row)
            progress[question.id] = row
        }
        let retired = row.record(correct: correct, at: date, config: config)

        context.insert(QuizAnswerRecord(questionId: question.id, topicId: topic.id, correct: correct, answeredAt: date))
        try pruneHistory(topicId: topic.id)

        let sticky: TopicProgress
        if let existing = try topicProgress(topicId: topic.id) {
            sticky = existing
        } else {
            sticky = TopicProgress(topicId: topic.id)
            context.insert(sticky)
        }
        let earned = TierGate.unlockedTiers(
            tallies: Self.tallies(questions: topic.questions, progress: progress),
            level: level,
            alreadyUnlocked: sticky.unlockedTiers,
            config: config
        )
        let unlocked = sticky.unlock(earned, at: date)
        if !unlocked.isEmpty {
            Logger.quiz.info("Unlocked tiers: \(unlocked.map(\.rawValue).joined(separator: ","), privacy: .public)")
        }
        return AnswerResult(retired: retired, unlocked: unlocked)
    }

    /// Keeps the newest `answerHistoryCap` records for the topic.
    private func pruneHistory(topicId: String) throws {
        var descriptor = FetchDescriptor<QuizAnswerRecord>(
            predicate: #Predicate { $0.topicId == topicId },
            sortBy: [SortDescriptor(\.answeredAt, order: .reverse)]
        )
        descriptor.fetchOffset = config.answerHistoryCap
        for old in try context.fetch(descriptor) {
            context.delete(old)
        }
    }

    // MARK: Pure helpers (also used by views with @Query results)

    /// Per-tier totals and retired counts for a topic's questions.
    static func tallies(questions: [Question], progress: [String: QuestionProgress]) -> [Difficulty: TierTally] {
        var result: [Difficulty: TierTally] = [:]
        for question in questions {
            result[question.difficulty, default: TierTally()].total += 1
            if progress[question.id]?.isRetired == true {
                result[question.difficulty, default: TierTally()].retired += 1
            }
        }
        return result
    }

    /// Pass `now` to count retired questions that are due for review as
    /// active (what buildQuiz will return to the pool), for UI counts.
    static func candidates(
        questions: [Question],
        progress: [String: QuestionProgress],
        now: Date? = nil,
        config: GatingConfig = .standard
    ) -> [PoolCandidate] {
        questions
            .sorted { $0.id < $1.id } // stable input → deterministic output for a seed
            .map { question in
                let row = progress[question.id]
                var active = row?.isRetired != true
                if !active, let now, let retiredAt = row?.retiredAt {
                    active = now >= retiredAt.addingTimeInterval(TimeInterval(config.reviewAfterDays) * 86_400)
                }
                return PoolCandidate(id: question.id, difficulty: question.difficulty, isActive: active)
            }
    }

    /// Correct share of the newest `window` records; nil when there are none.
    static func accuracy(of records: [QuizAnswerRecord], window: Int) -> Double? {
        let recent = records.sorted { $0.answeredAt > $1.answeredAt }.prefix(window)
        guard !recent.isEmpty else { return nil }
        return Double(recent.filter(\.correct).count) / Double(recent.count)
    }

    /// Lock state + reasons for the quiz UI ("Retire 3 more Medium questions").
    static func availability(
        questions: [Question],
        progress: [String: QuestionProgress],
        sticky: Set<Difficulty>,
        xp: Int,
        config: GatingConfig = .standard
    ) -> [TierAvailability] {
        TierGate.availability(
            tallies: tallies(questions: questions, progress: progress),
            xp: xp,
            level: LevelCalculator.level(forXP: xp),
            alreadyUnlocked: sticky,
            config: config,
            noun: "questions",
            verb: "Retire"
        )
    }
}
