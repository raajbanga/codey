import Foundation
import Supabase

/// RemoteDeckStore over PostgREST (supabase/migrations). RLS limits every
/// query to the signed-in owner, and owner_id defaults to auth.uid() on
/// insert, so the client never sends it. Each upsert is one request (NFR-02).
struct SupabaseDataClient: RemoteDeckStore {
    let client: SupabaseClient

    /// Rows per pull request. Must not exceed the project's PostgREST
    /// max-rows (1000 on Supabase), or a full page reads as the last one.
    var pageSize = 1000

    /// PostgREST's own coders (its date handling) plus snake_case keys, so
    /// the row types below need no CodingKeys. Pass to `SupabaseClientOptions(db:)`.
    static let databaseOptions: SupabaseClientOptions.DatabaseOptions = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = PostgrestClient.Configuration.jsonEncoder.dateEncodingStrategy
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = PostgrestClient.Configuration.jsonDecoder.dateDecodingStrategy
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return .init(encoder: encoder, decoder: decoder)
    }()

    /// ISO 8601 with milliseconds, for the server_updated_at filter.
    private static let timestampStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    func upsertDecks(_ decks: [DeckPayload]) async throws -> [UUID: Date] {
        guard !decks.isEmpty else { return [:] }
        let rows: [DeckVersionRow] = try await client.from("decks")
            .upsert(decks.map(DeckRow.init), onConflict: "id")
            .select("id,server_updated_at")
            .execute()
            .value
        return Dictionary(rows.map { ($0.id, $0.serverUpdatedAt) }, uniquingKeysWith: { _, last in last })
    }

    func upsertCards(_ cards: [RemoteCard]) async throws {
        guard !cards.isEmpty else { return }
        try await client.from("flashcards")
            .upsert(cards.map(CardRow.init), onConflict: "id", returning: .minimal)
            .execute()
    }

    func fetchChanges(since cursor: Date?) async throws -> RemoteChanges {
        let since = cursor?.formatted(Self.timestampStyle)
        async let deckRows: [DeckRow] = fetchAll("decks", columns: DeckRow.columns, since: since)
        async let cardRows: [CardRow] = fetchAll("flashcards", columns: CardRow.columns, since: since)
        let (decks, cards) = try await (deckRows, cardRows)
        // Both tables are read to the end, so the newest row of either is a
        // safe next cursor.
        let cursor = (decks.map(\.serverUpdatedAt) + cards.map(\.serverUpdatedAt)).compactMap { $0 }.max()
        return RemoteChanges(decks: decks.map(\.payload), cards: cards.map(\.remoteCard), cursor: cursor)
    }

    /// Every row changed after `since`, a page at a time. PostgREST caps each
    /// response at max-rows, so a single request can silently truncate.
    /// Ordered by (server_updated_at, id) so offsets are stable across pages.
    private func fetchAll<Row: Decodable & Sendable>(
        _ table: String, columns: String, since: String?, key: String = "id"
    ) async throws -> [Row] {
        var rows: [Row] = []
        while true {
            var query = client.from(table).select(columns)
            if let since {
                query = query.gt("server_updated_at", value: since)
            }
            let page: [Row] = try await query
                .order("server_updated_at")
                .order(key)
                .range(from: rows.count, to: rows.count + pageSize - 1)
                .execute()
                .value
            rows += page
            if page.count < pageSize { return rows }
        }
    }

    func fetchDeckVersions(ids: [UUID]) async throws -> [UUID: Date] {
        guard !ids.isEmpty else { return [:] }
        let rows: [DeckVersionRow] = try await client.from("decks")
            .select("id,server_updated_at")
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
        return Dictionary(rows.map { ($0.id, $0.serverUpdatedAt) }, uniquingKeysWith: { _, last in last })
    }

    func fetchDeckSnapshot(id: UUID) async throws -> RemoteDeckSnapshot? {
        let decks: [DeckRow] = try await client.from("decks")
            .select(DeckRow.columns)
            .eq("id", value: id.uuidString)
            .execute()
            .value
        guard let deck = decks.first else { return nil }
        let cards: [CardRow] = try await client.from("flashcards")
            .select(CardRow.columns)
            .eq("deck_id", value: id.uuidString)
            .execute()
            .value
        return RemoteDeckSnapshot(deck: deck.payload, cards: cards.map(\.remoteCard))
    }

    func fetchProfile() async throws -> ProfilePayload? {
        guard let userID = client.auth.currentUser?.id else { return nil }
        let rows: [ProfileRow] = try await client.from("profiles")
            .select("display_name,avatar_id,total_xp,solved_exercise_ids")
            .eq("id", value: userID.uuidString)
            .execute()
            .value
        return rows.first.map { ProfilePayload(displayName: $0.displayName, avatarId: $0.avatarId, totalXP: $0.totalXp,
                                         solvedExerciseIds: $0.solvedExerciseIds ?? []) }
    }

    /// The row is created by the sign-up trigger, so this is an update (RLS
    /// has no insert policy on profiles).
    func upsertProfile(_ profile: ProfilePayload) async throws {
        guard let userID = client.auth.currentUser?.id else { return }
        try await client.from("profiles")
            .update(ProfileRow(displayName: profile.displayName, avatarId: profile.avatarId, totalXp: profile.totalXP,
                               solvedExerciseIds: profile.solvedExerciseIds), returning: .minimal)
            .eq("id", value: userID.uuidString)
            .execute()
    }

    func appendSyncLog(_ entries: [SyncLogEntry]) async throws {
        guard !entries.isEmpty else { return }
        try await client.from("sync_log")
            .insert(entries.map(SyncLogRow.init), returning: .minimal)
            .execute()
    }
}

// MARK: - FR-61 study progress

extension SupabaseDataClient {
    func fetchProgressChanges(since cursor: Date?) async throws -> RemoteProgressChanges {
        let since = cursor?.formatted(Self.timestampStyle)
        async let cardRows: [CardProgressRow] = fetchAll("card_progress", columns: CardProgressRow.columns, since: since, key: "card_id")
        async let questionRows: [QuestionProgressRow] = fetchAll("question_progress", columns: QuestionProgressRow.columns, since: since, key: "question_id")
        async let topicRows: [TopicProgressRow] = fetchAll("topic_progress", columns: TopicProgressRow.columns, since: since, key: "topic_id")
        async let answerRows: [QuizAnswerRow] = fetchAll("quiz_answers", columns: QuizAnswerRow.columns, since: since, key: "question_id")
        async let dayRows: [DailyActivityRow] = fetchAll("daily_activity", columns: DailyActivityRow.columns, since: since, key: "day")
        async let badgeRows: [BadgeAwardRow] = fetchAll("badge_awards", columns: BadgeAwardRow.columns, since: since, key: "badge")
        let (cards, questions, topics) = try await (cardRows, questionRows, topicRows)
        let (answers, days, badges) = try await (answerRows, dayRows, badgeRows)
        // Every table is read to the end, so the newest row of any is a safe cursor.
        let times: [Date?] = cards.map(\.serverUpdatedAt) + questions.map(\.serverUpdatedAt) + topics.map(\.serverUpdatedAt)
            + answers.map(\.serverUpdatedAt) + days.map(\.serverUpdatedAt) + badges.map(\.serverUpdatedAt)
        return RemoteProgressChanges(
            progress: ProgressBatch(
                cards: cards.map(\.payload), questions: questions.map(\.payload), topics: topics.map(\.payload),
                answers: answers.map(\.payload), days: days.map(\.payload), badges: badges.map(\.payload)
            ),
            cursor: times.compactMap { $0 }.max()
        )
    }

    /// One request per table (NFR-02). owner_id is sent so the conflict
    /// target (owner_id, key) matches; RLS rejects any other owner.
    func upsertProgress(_ batch: ProgressBatch) async throws {
        guard let userID = client.auth.currentUser?.id else { return }
        if !batch.cards.isEmpty {
            try await client.from("card_progress")
                .upsert(batch.cards.map { CardProgressRow($0, ownerId: userID) }, onConflict: "owner_id,card_id", returning: .minimal)
                .execute()
        }
        if !batch.questions.isEmpty {
            try await client.from("question_progress")
                .upsert(batch.questions.map { QuestionProgressRow($0, ownerId: userID) }, onConflict: "owner_id,question_id", returning: .minimal)
                .execute()
        }
        if !batch.topics.isEmpty {
            try await client.from("topic_progress")
                .upsert(batch.topics.map { TopicProgressRow($0, ownerId: userID) }, onConflict: "owner_id,topic_id", returning: .minimal)
                .execute()
        }
        // Append-only: a resent answer is skipped (ON CONFLICT DO NOTHING),
        // so there's no update policy to need.
        for chunk in batch.answers.chunked(into: 500) {
            try await client.from("quiz_answers")
                .upsert(chunk.map { QuizAnswerRow($0, ownerId: userID) }, onConflict: "owner_id,question_id,answered_at",
                        returning: .minimal, ignoreDuplicates: true)
                .execute()
        }
        if !batch.days.isEmpty {
            try await client.from("daily_activity")
                .upsert(batch.days.map { DailyActivityRow($0, ownerId: userID) }, onConflict: "owner_id,device_id,day", returning: .minimal)
                .execute()
        }
        if !batch.badges.isEmpty {
            try await client.from("badge_awards")
                .upsert(batch.badges.map { BadgeAwardRow($0, ownerId: userID) }, onConflict: "owner_id,badge", returning: .minimal)
                .execute()
        }
    }
}

extension SupabaseDataClient {
    /// `returning: .minimal`: there's no select policy on feedback_reports,
    /// so asking for the row back would fail RLS.
    func submitFeedback(_ report: FeedbackReportPayload) async throws {
        try await client.from("feedback_reports")
            .insert(FeedbackReportRow(report), returning: .minimal)
            .execute()
    }
}

// MARK: - Groups + leaderboard (S3-D)

extension SupabaseDataClient {
    func fetchGroups() async throws -> [GroupSummary] {
        let rows: [GroupRow] = try await client.from("groups")
            .select(GroupRow.columns)
            .order("created_at")
            .execute()
            .value
        return rows.map(\.summary)
    }

    /// Inserted without RETURNING: the creator becomes a member in an AFTER
    /// trigger, which a RETURNING visibility check wouldn't see yet.
    func createGroup(id: UUID, name: String) async throws -> GroupSummary {
        try await client.from("groups")
            .insert(NewGroupRow(id: id, name: name), returning: .minimal)
            .execute()
        let rows: [GroupRow] = try await client.from("groups")
            .select(GroupRow.columns)
            .eq("id", value: id.uuidString)
            .execute()
            .value
        guard let row = rows.first else { throw GroupError.notFound }
        return row.summary
    }

    func joinGroup(code: String) async throws -> GroupSummary {
        do {
            let row: GroupRow = try await client.rpc("join_group", params: ["code": code])
                .execute()
                .value
            return row.summary
        } catch let error as PostgrestError where error.code == "P0002" {
            throw GroupError.invalidCode
        }
    }

    /// RLS only lets you delete your own membership.
    func leaveGroup(id: UUID) async throws {
        try await client.from("group_members")
            .delete(returning: .minimal)
            .eq("group_id", value: id.uuidString)
            .execute()
    }

    func fetchLeaderboard(groupID: UUID) async throws -> [LeaderboardEntry] {
        let rows: [LeaderboardRow] = try await client.from("group_leaderboard")
            .select("user_id,display_name,avatar_id,xp")
            .eq("group_id", value: groupID.uuidString)
            .execute()
            .value
        return rows.map { LeaderboardEntry(userId: $0.userId, displayName: $0.displayName, avatarId: $0.avatarId, xp: $0.xp) }
    }

    /// owner_id is sent (the upsert's conflict target) and checked by RLS.
    func upsertWeeklyXP(weekStart: String, xp: Int) async throws {
        guard let userID = client.auth.currentUser?.id else { return }
        try await client.from("weekly_xp")
            .upsert(WeeklyXPRow(ownerId: userID, weekStart: weekStart, xp: xp), onConflict: "owner_id,week_start", returning: .minimal)
            .execute()
    }
}

private struct GroupRow: Decodable {
    static let columns = "id,name,invite_code"

    var id: UUID
    var name: String
    var inviteCode: String


    var summary: GroupSummary { GroupSummary(id: id, name: name, inviteCode: inviteCode) }
}

/// invite_code and created_by are set by the server trigger.
private struct NewGroupRow: Encodable {
    var id: UUID
    var name: String
}

private struct LeaderboardRow: Decodable {
    var userId: UUID
    var displayName: String
    var avatarId: String?
    var xp: Int

}

private struct WeeklyXPRow: Encodable {
    var ownerId: UUID
    var weekStart: String
    var xp: Int

}

// MARK: - Rows (camelCase here, snake_case on the wire via `databaseOptions`)

/// owner_id is left to the column default, auth.uid().
private struct FeedbackReportRow: Encodable {
    var id: UUID
    var description: String
    var appVersion: String?
    var osVersion: String?


    init(_ payload: FeedbackReportPayload) {
        id = payload.id
        description = payload.description
        appVersion = payload.appVersion
        osVersion = payload.osVersion
    }
}

private struct DeckRow: Codable {
    static let columns = "id,title,topic_id,created_at,updated_at,deleted_at,server_updated_at"

    var id: UUID
    var title: String
    var topicId: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    /// Never sent: the server sets it.
    var serverUpdatedAt: Date?


    init(_ payload: DeckPayload) {
        id = payload.id
        title = payload.title
        topicId = payload.topicId
        createdAt = payload.createdAt
        updatedAt = payload.updatedAt
        deletedAt = payload.deletedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(topicId, forKey: .topicId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        // Explicit null, so an un-delete (later edit wins) clears the tombstone.
        try container.encode(deletedAt, forKey: .deletedAt)
    }

    var payload: DeckPayload {
        DeckPayload(id: id, title: title, topicId: topicId, createdAt: createdAt, updatedAt: updatedAt,
                    deletedAt: deletedAt, serverUpdatedAt: serverUpdatedAt)
    }
}

private struct DeckVersionRow: Decodable {
    var id: UUID
    var serverUpdatedAt: Date

}

/// Mastery isn't a flashcards column: it syncs per user in card_progress (FR-61).
private struct CardRow: Codable {
    static let columns = "id,deck_id,prompt,answer,code_language,code_source,difficulty,sort_index,created_at,updated_at,deleted_at,is_hidden,server_updated_at"

    var id: UUID
    var deckId: UUID
    var prompt: String
    var answer: String
    var codeLanguage: String?
    var codeSource: String?
    var difficulty: Difficulty?
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    /// Rows written before the column existed decode as visible.
    var isHidden: Bool?
    var serverUpdatedAt: Date?

    init(_ remote: RemoteCard) {
        let card = remote.card
        let now = Date.now
        id = card.id ?? UUID()
        deckId = remote.deckId
        prompt = card.prompt
        answer = card.answer
        codeLanguage = card.codeLanguage
        codeSource = card.codeSource
        difficulty = card.difficulty
        sortIndex = card.sortIndex
        createdAt = card.createdAt ?? now
        updatedAt = card.updatedAt ?? now
        deletedAt = card.deletedAt
        isHidden = card.isHidden ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(deckId, forKey: .deckId)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(answer, forKey: .answer)
        // Explicit nulls: removing a snippet, tier, or tombstone must clear it remotely.
        try container.encode(codeLanguage, forKey: .codeLanguage)
        try container.encode(codeSource, forKey: .codeSource)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(sortIndex, forKey: .sortIndex)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(deletedAt, forKey: .deletedAt)
        try container.encode(isHidden ?? false, forKey: .isHidden)
    }

    var remoteCard: RemoteCard {
        RemoteCard(deckId: deckId, card: FlashcardPayload(
            id: id, prompt: prompt, answer: answer, codeLanguage: codeLanguage, codeSource: codeSource,
            difficulty: difficulty, sortIndex: sortIndex, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt,
            isHidden: isHidden
        ))
    }
}

private struct ProfileRow: Codable {
    var displayName: String
    var avatarId: String?
    /// Not `totalXP`: the snake-case decoder maps total_xp to `totalXp`.
    var totalXp: Int
    /// Optional so an older row (before S43) still decodes.
    var solvedExerciseIds: [String]?
}

private struct SyncLogRow: Encodable {
    var entity: String
    var entityId: UUID
    var op: String
    var clientTs: Date
    var deviceId: String?


    init(_ entry: SyncLogEntry) {
        entity = entry.entity.rawValue
        entityId = entry.entityId
        op = entry.op.rawValue
        clientTs = entry.clientTimestamp
        deviceId = entry.deviceId
    }
}

// MARK: - FR-61 progress rows
// Optional columns are encoded as explicit nulls: an upsert that leaves a
// column out keeps the old value, so "Again" after retirement must send
// retired_at = null to clear it.

struct CardProgressRow: Codable {
    static let columns = "card_id,mastery_score,last_reviewed_at,retired_at,server_updated_at"

    var ownerId: UUID?
    var cardId: UUID
    var masteryScore: Int
    var lastReviewedAt: Date
    var retiredAt: Date?
    var serverUpdatedAt: Date?

    init(_ payload: CardProgressPayload, ownerId: UUID) {
        self.ownerId = ownerId
        cardId = payload.cardId
        masteryScore = payload.masteryScore
        lastReviewedAt = payload.lastReviewedAt
        retiredAt = payload.retiredAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(cardId, forKey: .cardId)
        try container.encode(masteryScore, forKey: .masteryScore)
        try container.encode(lastReviewedAt, forKey: .lastReviewedAt)
        try container.encode(retiredAt, forKey: .retiredAt)
    }

    var payload: CardProgressPayload {
        CardProgressPayload(cardId: cardId, masteryScore: masteryScore, lastReviewedAt: lastReviewedAt, retiredAt: retiredAt)
    }
}

struct QuestionProgressRow: Codable {
    static let columns = "question_id,topic_id,difficulty,consecutive_correct,total_attempts,total_correct,retired_at,is_review,last_answered_at,server_updated_at"

    var ownerId: UUID?
    var questionId: String
    var topicId: String
    var difficulty: Difficulty
    var consecutiveCorrect: Int
    var totalAttempts: Int
    var totalCorrect: Int
    var retiredAt: Date?
    var isReview: Bool
    var lastAnsweredAt: Date
    var serverUpdatedAt: Date?

    init(_ payload: QuestionProgressPayload, ownerId: UUID) {
        self.ownerId = ownerId
        questionId = payload.questionId
        topicId = payload.topicId
        difficulty = payload.difficulty
        consecutiveCorrect = payload.consecutiveCorrect
        totalAttempts = payload.totalAttempts
        totalCorrect = payload.totalCorrect
        retiredAt = payload.retiredAt
        isReview = payload.isReview
        lastAnsweredAt = payload.lastAnsweredAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(questionId, forKey: .questionId)
        try container.encode(topicId, forKey: .topicId)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(consecutiveCorrect, forKey: .consecutiveCorrect)
        try container.encode(totalAttempts, forKey: .totalAttempts)
        try container.encode(totalCorrect, forKey: .totalCorrect)
        try container.encode(retiredAt, forKey: .retiredAt)
        try container.encode(isReview, forKey: .isReview)
        try container.encode(lastAnsweredAt, forKey: .lastAnsweredAt)
    }

    var payload: QuestionProgressPayload {
        QuestionProgressPayload(
            questionId: questionId, topicId: topicId, difficulty: difficulty,
            consecutiveCorrect: consecutiveCorrect, totalAttempts: totalAttempts, totalCorrect: totalCorrect,
            retiredAt: retiredAt, isReview: isReview, lastAnsweredAt: lastAnsweredAt
        )
    }
}

private struct TopicProgressRow: Codable {
    static let columns = "topic_id,medium_unlocked_at,hard_unlocked_at,server_updated_at"

    var ownerId: UUID?
    var topicId: String
    var mediumUnlockedAt: Date?
    var hardUnlockedAt: Date?
    var serverUpdatedAt: Date?

    init(_ payload: TopicProgressPayload, ownerId: UUID) {
        self.ownerId = ownerId
        topicId = payload.topicId
        mediumUnlockedAt = payload.mediumUnlockedAt
        hardUnlockedAt = payload.hardUnlockedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(topicId, forKey: .topicId)
        // Null is safe here: the server keeps the earliest non-null unlock.
        try container.encode(mediumUnlockedAt, forKey: .mediumUnlockedAt)
        try container.encode(hardUnlockedAt, forKey: .hardUnlockedAt)
    }

    var payload: TopicProgressPayload {
        TopicProgressPayload(topicId: topicId, mediumUnlockedAt: mediumUnlockedAt, hardUnlockedAt: hardUnlockedAt)
    }
}

// MARK: - FR-61 history rows (S43)

private struct QuizAnswerRow: Codable {
    static let columns = "question_id,topic_id,correct,answered_at,server_updated_at"

    var ownerId: UUID?
    var questionId: String
    var topicId: String
    var correct: Bool
    var answeredAt: Date
    var serverUpdatedAt: Date?

    init(_ payload: QuizAnswerPayload, ownerId: UUID) {
        self.ownerId = ownerId
        questionId = payload.questionId
        topicId = payload.topicId
        correct = payload.correct
        answeredAt = payload.answeredAt
    }

    var payload: QuizAnswerPayload {
        QuizAnswerPayload(questionId: questionId, topicId: topicId, correct: correct, answeredAt: answeredAt)
    }
}

private struct DailyActivityRow: Codable {
    static let columns = "device_id,day,cards_rated,quiz_answers,server_updated_at"

    var ownerId: UUID?
    var deviceId: String
    var day: String
    var cardsRated: Int
    var quizAnswers: Int
    var serverUpdatedAt: Date?

    init(_ payload: DailyActivityPayload, ownerId: UUID) {
        self.ownerId = ownerId
        deviceId = payload.deviceId
        day = payload.day
        cardsRated = payload.cardsRated
        quizAnswers = payload.quizAnswers
    }

    var payload: DailyActivityPayload {
        DailyActivityPayload(deviceId: deviceId, day: day, cardsRated: cardsRated, quizAnswers: quizAnswers)
    }
}

private struct BadgeAwardRow: Codable {
    static let columns = "badge,earned_at,server_updated_at"

    var ownerId: UUID?
    var badge: String
    var earnedAt: Date
    var serverUpdatedAt: Date?

    init(_ payload: BadgeAwardPayload, ownerId: UUID) {
        self.ownerId = ownerId
        badge = payload.badge
        earnedAt = payload.earnedAt
    }

    var payload: BadgeAwardPayload { BadgeAwardPayload(badge: badge, earnedAt: earnedAt) }
}
