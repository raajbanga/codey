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

// MARK: - Rows (snake_case, matching the migrations)

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
