import Foundation
import SwiftData

/// FR-61: maps local study progress to and from the progress tables, and
/// applies the merge rules on pull (the server applies the same ones on push):
///   - card mastery and quiz progress: the latest review wins, by the
///     client timestamp (lastReviewedAt / lastAnsweredAt);
///   - tier unlocks: sticky, the earliest non-nil date per tier is kept;
///   - quiz answers (S43): append-only, a known answer is skipped;
///   - daily activity (S43): per device, the larger counter wins. This
///     device's rows merge into DailyActivity, other devices' into
///     DeviceDayActivity; a day's total is the sum (StreakCalculator);
///   - badges (S43): one per badge, the earliest earned date is kept.
/// Not queued: each sync cycle pulls, then pushes rows reviewed after the
/// last push (SyncEngine.syncProgress).
@MainActor
struct ProgressSync {
    let context: ModelContext
    /// This device's daily_activity key (identifierForVendor).
    var deviceId: String = "local"

    // MARK: Push

    /// Local rows changed after `marker` (every row with progress when nil).
    /// History (answers, days, badges) uses `historySince`, which defaults
    /// to `marker`; nil sends all of it (the first sync after S43).
    func localChanges(since marker: Date?, historySince: Date?? = nil) throws -> ProgressBatch {
        let after = marker ?? .distantPast
        let historyMarker = historySince ?? marker
        let historyAfter = historyMarker ?? .distantPast
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
        let answers = try context.fetch(FetchDescriptor<QuizAnswerRecord>(predicate: #Predicate { $0.answeredAt > historyAfter }))
            .map { QuizAnswerPayload(questionId: $0.questionId, topicId: $0.topicId, correct: $0.correct, answeredAt: $0.answeredAt) }
        let badges = try context.fetch(FetchDescriptor<BadgeAward>(predicate: #Predicate { $0.earnedAt > historyAfter }))
            .map { BadgeAwardPayload(badge: $0.badgeRaw, earnedAt: $0.earnedAt) }
        return ProgressBatch(cards: cards, questions: questions, topics: topics,
                             answers: answers, days: try localDays(since: historyMarker), badges: badges)
    }

    /// DailyActivity has no timestamp, so after the first push this sends
    /// the days from the one before the last push on (a push late at night
    /// can be followed by more answers that day). Days only grow, and the
    /// server keeps the larger counter, so resending is harmless.
    private func localDays(since marker: Date?) throws -> [DailyActivityPayload] {
        var descriptor = FetchDescriptor<DailyActivity>()
        if let marker {
            let calendar = Calendar.current
            let from = DailyActivity.dayKey(for: calendar.date(byAdding: .day, value: -1, to: marker) ?? marker, calendar: calendar)
            descriptor.predicate = #Predicate { $0.day >= from }
        }
        return try context.fetch(descriptor)
            .filter { $0.cardsRated > 0 || $0.quizAnswers > 0 }
            .map { DailyActivityPayload(deviceId: deviceId, day: $0.day, cardsRated: $0.cardsRated, quizAnswers: $0.quizAnswers) }
    }

    // MARK: Pull

    /// Applies remote rows that win the merge. Does not save.
    func apply(_ batch: ProgressBatch) throws {
        try applyCards(batch.cards)
        try applyQuestions(batch.questions)
        try applyTopics(batch.topics)
        try applyAnswers(batch.answers)
        try applyDays(batch.days)
        try applyBadges(batch.badges)
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

    /// Inserts answers this device doesn't have. The same answer comes back
    /// with the server's microsecond time, so "same" allows 1 ms.
    private func applyAnswers(_ rows: [QuizAnswerPayload]) throws {
        guard !rows.isEmpty else { return }
        let ids = Set(rows.map(\.questionId))
        var known: [String: [Date]] = [:]
        for record in try context.fetch(FetchDescriptor<QuizAnswerRecord>(predicate: #Predicate { ids.contains($0.questionId) })) {
            known[record.questionId, default: []].append(record.answeredAt)
        }
        for row in rows {
            guard !(known[row.questionId] ?? []).contains(where: { abs($0.timeIntervalSince(row.answeredAt)) < 0.001 }) else { continue }
            context.insert(QuizAnswerRecord(questionId: row.questionId, topicId: row.topicId, correct: row.correct, answeredAt: row.answeredAt))
            known[row.questionId, default: []].append(row.answeredAt)
        }
    }

    /// This device's own rows come back after a reinstall (same vendor id):
    /// they raise DailyActivity. Other devices' rows go to DeviceDayActivity.
    private func applyDays(_ rows: [DailyActivityPayload]) throws {
        guard !rows.isEmpty else { return }
        var own = try context.fetch(FetchDescriptor<DailyActivity>()).keyed(by: \.day)
        var others = try context.fetch(FetchDescriptor<DeviceDayActivity>()).keyed(by: \.key)
        for row in rows {
            if row.deviceId == deviceId {
                let day = own[row.day] ?? {
                    let new = DailyActivity(day: row.day)
                    context.insert(new)
                    return new
                }()
                own[row.day] = day
                day.cardsRated = max(day.cardsRated, row.cardsRated)
                day.quizAnswers = max(day.quizAnswers, row.quizAnswers)
            } else {
                let key = "\(row.deviceId)|\(row.day)"
                let day = others[key] ?? {
                    let new = DeviceDayActivity(deviceId: row.deviceId, day: row.day)
                    context.insert(new)
                    return new
                }()
                others[key] = day
                day.cardsRated = max(day.cardsRated, row.cardsRated)
                day.quizAnswers = max(day.quizAnswers, row.quizAnswers)
            }
        }
    }

    private func applyBadges(_ rows: [BadgeAwardPayload]) throws {
        guard !rows.isEmpty else { return }
        var local = try context.fetch(FetchDescriptor<BadgeAward>()).keyed(by: \.badgeRaw)
        for row in rows {
            guard let badge = Badge(rawValue: row.badge) else { continue }
            if let existing = local[row.badge] {
                existing.earnedAt = min(existing.earnedAt, row.earnedAt)
            } else {
                let award = BadgeAward(badge: badge, earnedAt: row.earnedAt)
                context.insert(award)
                local[row.badge] = award
            }
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
