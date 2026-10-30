import Foundation
import Supabase

/// RemoteDeckStore over PostgREST (supabase/migrations). RLS limits every
/// query to the signed-in owner, and owner_id defaults to auth.uid() on
/// insert, so the client never sends it. Each upsert is one request (NFR-02).
struct SupabaseDataClient: RemoteDeckStore {
    let client: SupabaseClient

    /// ISO 8601 with milliseconds, for the server_updated_at filter.
    private static var timestampFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

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
        var decksQuery = client.from("decks").select(DeckRow.columns)
        var cardsQuery = client.from("flashcards").select(CardRow.columns)
        if let cursor {
            let since = Self.timestampFormatter.string(from: cursor)
            decksQuery = decksQuery.gt("server_updated_at", value: since)
            cardsQuery = cardsQuery.gt("server_updated_at", value: since)
        }
        let decks: [DeckRow] = try await decksQuery.order("server_updated_at").execute().value
        let cards: [CardRow] = try await cardsQuery.order("server_updated_at").execute().value
        let cursor = (decks.map(\.serverUpdatedAt) + cards.map(\.serverUpdatedAt)).compactMap { $0 }.max()
        return RemoteChanges(decks: decks.map(\.payload), cards: cards.map(\.remoteCard), cursor: cursor)
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
            .select("display_name,avatar_id,total_xp")
            .eq("id", value: userID.uuidString)
            .execute()
            .value
        return rows.first.map { ProfilePayload(displayName: $0.displayName, avatarId: $0.avatarId, totalXP: $0.totalXP) }
    }

    /// The row is created by the sign-up trigger, so this is an update (RLS
    /// has no insert policy on profiles).
    func upsertProfile(_ profile: ProfilePayload) async throws {
        guard let userID = client.auth.currentUser?.id else { return }
        try await client.from("profiles")
            .update(ProfileRow(displayName: profile.displayName, avatarId: profile.avatarId, totalXP: profile.totalXP), returning: .minimal)
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

    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
    }

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

    enum CodingKeys: String, CodingKey {
        case xp
        case userId = "user_id"
        case displayName = "display_name"
        case avatarId = "avatar_id"
    }
}

private struct WeeklyXPRow: Encodable {
    var ownerId: UUID
    var weekStart: String
    var xp: Int

    enum CodingKeys: String, CodingKey {
        case xp
        case ownerId = "owner_id"
        case weekStart = "week_start"
    }
}

// MARK: - Rows (snake_case, matching the migrations)

/// owner_id is left to the column default, auth.uid().
private struct FeedbackReportRow: Encodable {
    var id: UUID
    var description: String
    var appVersion: String?
    var osVersion: String?

    enum CodingKeys: String, CodingKey {
        case id, description
        case appVersion = "app_version"
        case osVersion = "os_version"
    }

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

    enum CodingKeys: String, CodingKey {
        case id, title
        case topicId = "topic_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

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

    enum CodingKeys: String, CodingKey {
        case id
        case serverUpdatedAt = "server_updated_at"
    }
}

/// Mastery isn't synced (D10: progress stays local), so it has no column.
private struct CardRow: Codable {
    static let columns = "id,deck_id,prompt,answer,code_language,code_source,difficulty,sort_index,created_at,updated_at,deleted_at,server_updated_at"

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
    var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, prompt, answer, difficulty
        case deckId = "deck_id"
        case codeLanguage = "code_language"
        case codeSource = "code_source"
        case sortIndex = "sort_index"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

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
    }

    var remoteCard: RemoteCard {
        RemoteCard(deckId: deckId, card: FlashcardPayload(
            id: id, prompt: prompt, answer: answer, codeLanguage: codeLanguage, codeSource: codeSource,
            difficulty: difficulty, sortIndex: sortIndex, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt
        ))
    }
}

private struct ProfileRow: Codable {
    var displayName: String
    var avatarId: String?
    var totalXP: Int

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarId = "avatar_id"
        case totalXP = "total_xp"
    }
}

private struct SyncLogRow: Encodable {
    var entity: String
    var entityId: UUID
    var op: String
    var clientTs: Date
    var deviceId: String?

    enum CodingKeys: String, CodingKey {
        case entity, op
        case entityId = "entity_id"
        case clientTs = "client_ts"
        case deviceId = "device_id"
    }

    init(_ entry: SyncLogEntry) {
        entity = entry.entity.rawValue
        entityId = entry.entityId
        op = entry.op.rawValue
        clientTs = entry.clientTimestamp
        deviceId = entry.deviceId
    }
}
