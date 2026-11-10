import Foundation
import SwiftData

/// FR-61: maps local study progress to and from the progress tables, and
/// applies the merge rules on pull (the server applies the same ones on push):
///   - card mastery and quiz progress: the latest review wins, by the
///     client timestamp (lastReviewedAt / lastAnsweredAt);
///   - tier unlocks: sticky, the earliest non-nil date per tier is kept.
/// Not queued: each sync cycle pulls, then pushes rows reviewed after the
/// last push (SyncEngine.syncProgress).
@MainActor
struct ProgressSync {
    let context: ModelContext

    // MARK: Push

    /// Local rows changed after `marker` (every row with progress when nil).
    func localChanges(since marker: Date?) throws -> ProgressBatch {
        let after = marker ?? .distantPast
        let cards = try context.fetch(FetchDescriptor<Flashcard>(predicate: #Predicate { $0.lastReviewedAt != nil }))
            .compactMap { card -> CardProgressPayload? in
                guard card.deletedAt == nil, let reviewed = card.lastReviewedAt, reviewed > after else { return nil }
                return CardProgressPayload(cardId: card.id, masteryScore: card.masteryScore,
                                           lastReviewedAt: reviewed, retiredAt: card.retiredAt)
            }
        let questions = try context.fetch(FetchDescriptor<QuestionProgress>(predicate: #Predicate { $0.lastAnsweredAt != nil }))
            .compactMap { row -> QuestionProgressPayload? in
                guard let answered = row.lastAnsweredAt, answered > after else { return nil }
                return QuestionProgressPayload(
                    questionId: row.questionId, topicId: row.topicId, difficulty: row.difficulty,
                    consecutiveCorrect: row.consecutiveCorrect, totalAttempts: row.totalAttempts,
                    totalCorrect: row.totalCorrect, retiredAt: row.retiredAt, isReview: row.isReview,
                    lastAnsweredAt: answered
                )
            }
        let topics = try context.fetch(FetchDescriptor<TopicProgress>())
            .compactMap { row -> TopicProgressPayload? in
                let latest = [row.mediumUnlockedAt, row.hardUnlockedAt].compactMap { $0 }.max()
                guard let latest, latest > after else { return nil }
                return TopicProgressPayload(topicId: row.topicId, mediumUnlockedAt: row.mediumUnlockedAt,
                                            hardUnlockedAt: row.hardUnlockedAt)
            }
        return ProgressBatch(cards: cards, questions: questions, topics: topics)
    }

    // MARK: Pull

    /// Applies remote rows that win the merge. Does not save.
    func apply(_ batch: ProgressBatch) throws {
        try applyCards(batch.cards)
        try applyQuestions(batch.questions)
        try applyTopics(batch.topics)
    }

    private func applyCards(_ rows: [CardProgressPayload]) throws {
        guard !rows.isEmpty else { return }
        let ids = Set(rows.map(\.cardId))
        let cards = try context.fetch(FetchDescriptor<Flashcard>(predicate: #Predicate { ids.contains($0.id) }))
            .keyed(by: \.id)
        for row in rows {
            // A card this device doesn't have (a deck not pulled yet, or
            // deleted) is skipped; its row is pulled again when it changes.
            guard let card = cards[row.cardId] else { continue }
            guard Self.remoteWins(row.lastReviewedAt, over: card.lastReviewedAt) else { continue }
            card.applyRemoteProgress(score: row.masteryScore, lastReviewedAt: row.lastReviewedAt, retiredAt: row.retiredAt)
        }
    }

    private func applyQuestions(_ rows: [QuestionProgressPayload]) throws {
        guard !rows.isEmpty else { return }
        var local = try context.fetch(FetchDescriptor<QuestionProgress>()).keyed(by: \.questionId)
        for row in rows {
            let progress: QuestionProgress
            if let existing = local[row.questionId] {
                guard Self.remoteWins(row.lastAnsweredAt, over: existing.lastAnsweredAt) else { continue }
                progress = existing
            } else {
                progress = QuestionProgress(questionId: row.questionId, topicId: row.topicId, difficulty: row.difficulty)
                context.insert(progress)
                local[row.questionId] = progress
            }
            progress.topicId = row.topicId
            progress.difficulty = row.difficulty
            progress.consecutiveCorrect = row.consecutiveCorrect
            progress.totalAttempts = row.totalAttempts
            progress.totalCorrect = row.totalCorrect
            progress.retiredAt = row.retiredAt
            progress.isReview = row.isReview
            progress.lastAnsweredAt = row.lastAnsweredAt
        }
    }

    private func applyTopics(_ rows: [TopicProgressPayload]) throws {
        guard !rows.isEmpty else { return }
        var local = try context.fetch(FetchDescriptor<TopicProgress>()).keyed(by: \.topicId)
        for row in rows {
            let progress = local[row.topicId] ?? {
                let new = TopicProgress(topicId: row.topicId)
                context.insert(new)
                return new
            }()
            local[row.topicId] = progress
            progress.mediumUnlockedAt = Self.earliest(progress.mediumUnlockedAt, row.mediumUnlockedAt)
            progress.hardUnlockedAt = Self.earliest(progress.hardUnlockedAt, row.hardUnlockedAt)
        }
    }

    // MARK: Merge rules (shared with the SQL triggers)

    /// A remote review replaces the local one only when it's strictly newer.
    static func remoteWins(_ remote: Date, over local: Date?) -> Bool {
        guard let local else { return true }
        return remote > local
    }

    /// Sticky unlock: the earlier of two dates, ignoring nil (like SQL least()).
    static func earliest(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case let (a?, b?): min(a, b)
        case let (a?, nil): a
        case let (nil, b): b
        }
    }
}
