import Foundation
import Testing
@testable import codey

// SupabaseTestClient is DEBUG-only (NFR-26); the Release perf run
// (scripts/perf-report.sh) builds the test target without it.
#if DEBUG

/// SupabaseDataClient against a stubbed network: the exact PostgREST requests
/// (paths, filters, upsert headers, explicit nulls) and response decoding.
@Suite(.serialized)
struct SupabaseDataClientTests {
    private func makeClient(pageSize: Int = 1000) -> any RemoteDeckStore {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return SupabaseTestClient.dataClient(
            url: URL(string: "https://stub.supabase.co")!, key: "stub-key", configuration: configuration, pageSize: pageSize
        )
    }

    private let deckID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    @Test func upsertDecksIsOneMergingPostWithExplicitNulls() async throws {
        StubURLProtocol.reset(responseJSON: #"[{"id":"11111111-2222-3333-4444-555555555555","server_updated_at":"2026-10-08T03:00:00.123456+00:00"}]"#)
        let versions = try await makeClient().upsertDecks([
            DeckPayload(id: deckID, title: "T", topicId: "topic-x", createdAt: .now, updatedAt: .now),
        ])

        let request = try #require(StubURLProtocol.requests.only)
        #expect(request.method == "POST")
        #expect(request.url.path == "/rest/v1/decks")
        #expect(request.query["on_conflict"] == "id")
        #expect(request.query["select"] == "id,server_updated_at")
        #expect(request.headers["Prefer"]?.contains("resolution=merge-duplicates") == true)
        let rows = try #require(request.jsonArray)
        #expect(rows.count == 1)
        #expect(rows[0]["topic_id"] as? String == "topic-x")
        #expect(rows[0].keys.contains("deleted_at") && rows[0]["deleted_at"] is NSNull, "un-delete must send null")
        #expect(rows[0]["server_updated_at"] == nil, "the server sets the cursor")
        #expect(rows[0]["owner_id"] == nil, "owner_id defaults to auth.uid()")

        let version = try #require(versions[deckID])
        #expect(abs(version.timeIntervalSince1970 - 1_791_428_400.123) < 0.001)
    }

    @Test func upsertCardsSendsNullsAndNoMastery() async throws {
        StubURLProtocol.reset(responseJSON: "[]")
        try await makeClient().upsertCards([
            RemoteCard(deckId: deckID, card: FlashcardPayload(
                id: UUID(), prompt: "P", answer: "A", sortIndex: 3, masteryScore: 4, createdAt: .now, updatedAt: .now
            )),
        ])

        let request = try #require(StubURLProtocol.requests.only)
        #expect(request.url.path == "/rest/v1/flashcards")
        #expect(request.headers["Prefer"]?.contains("return=minimal") == true)
        let row = try #require(request.jsonArray?.first)
        #expect(row["deck_id"] as? String == deckID.uuidString)
        #expect(row["sort_index"] as? Int == 3)
        for key in ["code_language", "code_source", "difficulty", "deleted_at"] {
            #expect(row[key] is NSNull, "\(key) must be an explicit null")
        }
        #expect(row["mastery_score"] == nil && row["masteryScore"] == nil, "mastery stays local (D10)")
    }

    @Test func emptyBatchesMakeNoRequest() async throws {
        StubURLProtocol.reset(responseJSON: "[]")
        let client = makeClient()
        _ = try await client.upsertDecks([])
        try await client.upsertCards([])
        _ = try await client.fetchDeckVersions(ids: [])
        try await client.appendSyncLog([])
        #expect(StubURLProtocol.requests.isEmpty)
    }

    @Test func fetchChangesFiltersByCursorAndDecodesRows() async throws {
        StubURLProtocol.reset { url in
            url.path.hasSuffix("/decks")
                ? #"[{"id":"11111111-2222-3333-4444-555555555555","title":"T","topic_id":"t","created_at":"2026-10-01T00:00:00+00:00","updated_at":"2026-10-02T00:00:00+00:00","deleted_at":null,"server_updated_at":"2026-10-08T03:00:00.5+00:00"}]"#
                : #"[{"id":"99999999-2222-3333-4444-555555555555","deck_id":"11111111-2222-3333-4444-555555555555","prompt":"P","answer":"A","code_language":"python","code_source":"print(1)","difficulty":"easy","sort_index":0,"created_at":"2026-10-01T00:00:00+00:00","updated_at":"2026-10-01T00:00:00+00:00","deleted_at":null,"server_updated_at":"2026-10-08T03:00:01+00:00"}]"#
        }
        let cursor = Date(timeIntervalSince1970: 1_791_000_000)
        let changes = try await makeClient().fetchChanges(since: cursor)

        #expect(StubURLProtocol.requests.count == 2)
        for request in StubURLProtocol.requests {
            #expect(request.method == "GET")
            #expect(request.query["server_updated_at"]?.hasPrefix("gt.2026-") == true)
            #expect(request.query["order"]?.hasPrefix("server_updated_at.asc") == true)
        }
        #expect(changes.decks.map(\.id) == [deckID])
        #expect(changes.cards.first?.card.codeLanguage == "python")
        #expect(changes.cards.first?.card.difficulty == .easy)
        #expect(changes.cards.first?.deckId == deckID)
        // The cursor is the newest server_updated_at across both tables.
        #expect(changes.cursor == Date(timeIntervalSince1970: 1_791_428_401))
    }

    @Test func fetchChangesReadsEveryPage() async throws {
        // A server that caps responses at 2 rows: 3 changed decks need 2 pages.
        func deck(_ n: Int) -> String {
            #"{"id":"00000000-0000-0000-0000-00000000000\#(n)","title":"T","topic_id":"t","created_at":"2026-10-01T00:00:00+00:00","updated_at":"2026-10-01T00:00:00+00:00","deleted_at":null,"server_updated_at":"2026-10-08T03:00:0\#(n)+00:00"}"#
        }
        StubURLProtocol.reset { url in
            guard url.path.hasSuffix("/decks") else { return "[]" }
            let offset = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "offset" }?.value
            return offset == "0" ? "[\(deck(1)),\(deck(2))]" : "[\(deck(3))]"
        }
        let changes = try await makeClient(pageSize: 2).fetchChanges(since: nil)

        let deckRequests = StubURLProtocol.requests.filter { $0.url.path.hasSuffix("/decks") }
        #expect(deckRequests.map { $0.query["offset"] } == ["0", "2"])
        #expect(deckRequests.allSatisfy { $0.query["limit"] == "2" })
        #expect(deckRequests.allSatisfy { $0.query["order"]?.contains("id.asc") == true }, "ties need a stable order")
        #expect(changes.decks.count == 3)
        #expect(changes.cursor == Date(timeIntervalSince1970: 1_791_428_403))
    }

    @Test func deckVersionsUseAnInFilter() async throws {
        StubURLProtocol.reset(responseJSON: "[]")
        _ = try await makeClient().fetchDeckVersions(ids: [deckID])
        let request = try #require(StubURLProtocol.requests.only)
        #expect(request.query["id"] == "in.(\(deckID.uuidString))")
    }

    @Test func syncLogInsertsSnakeCaseRows() async throws {
        StubURLProtocol.reset(responseJSON: "[]")
        try await makeClient().appendSyncLog([
            SyncLogEntry(entity: .card, entityId: deckID, op: .delete, clientTimestamp: .now, deviceId: "dev"),
        ])
        let request = try #require(StubURLProtocol.requests.only)
        #expect(request.url.path == "/rest/v1/sync_log")
        let row = try #require(request.jsonArray?.first)
        #expect(row["entity"] as? String == "card")
        #expect(row["op"] as? String == "delete")
        #expect(row["entity_id"] as? String == deckID.uuidString)
        #expect(row["client_ts"] is String)
        #expect(row["device_id"] as? String == "dev")
    }

    @Test func profileCallsNeedASignedInUser() async throws {
        StubURLProtocol.reset(responseJSON: "[]")
        let client = makeClient()
        #expect(try await client.fetchProfile() == nil)
        try await client.upsertProfile(ProfilePayload(displayName: "x", avatarId: nil, totalXP: 1))
        #expect(StubURLProtocol.requests.isEmpty)
    }

    /// The row types rely on the client's snake_case coders, not
    /// CodingKeys. An all-caps acronym (`totalXP`) would not survive decoding.
    @Test func databaseCodersMapSnakeCase() throws {
        struct Row: Codable, Equatable {
            var avatarId: String?
            var totalXp: Int
            var serverUpdatedAt: Date
        }
        struct Acronym: Decodable { var totalXP: Int }
        let options = SupabaseDataClient.databaseOptions
        let json = Data(#"{"avatar_id":"fox","total_xp":120,"server_updated_at":"2026-10-08T03:00:00.123456+00:00"}"#.utf8)

        let row = try options.decoder.decode(Row.self, from: json)
        #expect(row.avatarId == "fox" && row.totalXp == 120)
        let encoded = try #require(JSONSerialization.jsonObject(with: options.encoder.encode(row)) as? [String: Any])
        #expect(Set(encoded.keys) == ["avatar_id", "total_xp", "server_updated_at"])
        #expect(throws: DecodingError.self) { try options.decoder.decode(Acronym.self, from: json) }
    }

    /// S37 interface fault (Activity 12.2): a nil `retiredAt` must go on the
    /// wire as an explicit `retired_at: null`. If the key were dropped, the
    /// upsert would keep the server's old value and a card or question
    /// un-retired by "Again" would stay retired on the other device.
    @Test func progressRowsSendRetiredAtAsExplicitNull() throws {
        let encoder = SupabaseDataClient.databaseOptions.encoder
        let owner = UUID()
        let card = CardProgressRow(
            CardProgressPayload(cardId: UUID(), masteryScore: 1, lastReviewedAt: .now, retiredAt: nil), ownerId: owner
        )
        let question = QuestionProgressRow(
            QuestionProgressPayload(
                questionId: "q1", topicId: "topic-swift", difficulty: .easy, consecutiveCorrect: 0,
                totalAttempts: 1, totalCorrect: 0, retiredAt: nil, isReview: false, lastAnsweredAt: .now
            ),
            ownerId: owner
        )
        for data in [try encoder.encode(card), try encoder.encode(question)] {
            let row = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(row.keys.contains("retired_at") && row["retired_at"] is NSNull, "retired_at must be an explicit null")
            #expect(row["owner_id"] as? String == owner.uuidString)
            #expect(row["server_updated_at"] == nil, "the server sets the cursor")
        }
    }

    @Test func serverErrorsThrow() async throws {
        StubURLProtocol.reset(status: 401, responseJSON: #"{"code":"42501","message":"permission denied"}"#)
        await #expect(throws: (any Error).self) {
            _ = try await makeClient().fetchChanges(since: nil)
        }
    }
}

/// Records every request and answers with canned JSON.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Recorded {
        let method: String
        let url: URL
        let headers: [String: String]
        let body: Data?

        var query: [String: String] {
            Dictionary(
                (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") },
                uniquingKeysWith: { _, last in last }
            )
        }

        var jsonArray: [[String: Any]]? {
            body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] }
        }
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var recorded: [Recorded] = []
    nonisolated(unsafe) private static var status = 200
    nonisolated(unsafe) private static var respond: (URL) -> String = { _ in "[]" }

    static var requests: [Recorded] { lock.withLock { recorded } }

    static func reset(status: Int = 200, responseJSON: String) {
        reset(status: status) { _ in responseJSON }
    }

    static func reset(status: Int = 200, respond: @escaping (URL) -> String) {
        lock.withLock {
            recorded = []
            Self.status = status
            Self.respond = respond
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        let entry = Recorded(
            method: request.httpMethod ?? "GET",
            url: url,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody ?? request.httpBodyStream.map(Self.read)
        )
        let (status, body) = Self.lock.withLock {
            Self.recorded.append(entry)
            return (Self.status, Self.respond(url))
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private extension Array {
    var only: Element? { count == 1 ? first : nil }
}
#endif
