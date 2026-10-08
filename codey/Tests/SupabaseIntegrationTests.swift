import Foundation
import SwiftData
import Testing
@testable import codey

/// Opt-in, against a real Supabase project (9.7). Runs only when these are
/// set in the test environment (prefix with TEST_RUNNER_ for xcodebuild):
///   SUPABASE_TEST_URL, SUPABASE_TEST_KEY,
///   SUPABASE_TEST_EMAIL_A, SUPABASE_TEST_PASSWORD_A,
///   SUPABASE_TEST_EMAIL_B, SUPABASE_TEST_PASSWORD_B
/// The two accounts must be email/password users in that project. Each test
/// deletes the decks it made.
@MainActor
@Suite(.serialized, .enabled(if: IntegrationEnvironment.current != nil, "Supabase test credentials not set"))
struct SupabaseIntegrationTests {
    private func signIn(_ account: IntegrationEnvironment.Account) async throws -> SupabaseTestAccounts.Session {
        let env = try #require(IntegrationEnvironment.current)
        return try await SupabaseTestAccounts.signIn(url: env.url, key: env.key, email: account.email, password: account.password)
    }

    private func harness(_ session: SupabaseTestAccounts.Session, reachable: Bool = true) throws -> (BackendFacade, ModelContext, MockReachability) {
        let context = try TestSupport.inMemoryContext()
        let reachability = MockReachability(isReachable: reachable)
        let facade = BackendFacade(
            context: context,
            auth: MockAuth(user: AppUser(id: session.userID, email: nil, displayName: nil)),
            remote: session.remote,
            reachability: reachability,
            cursors: SyncCursorStore(defaults: UserDefaults(suiteName: "codey-it-\(UUID().uuidString)")!),
            sleep: { _ in throw CancellationError() }
        )
        return (facade, context, reachability)
    }

    private func draft(_ title: String, cards: Int) -> DeckDraft {
        var draft = DeckDraft.new(topicId: "topic-data-structures")
        draft.title = title
        draft.cards = (1...cards).map { CardDraft(prompt: "Prompt \($0)", answer: "Answer \($0)") }
        return draft
    }

    /// NFR-02: a 100-card deck pushes in ≤ 5 s on Wi-Fi.
    @Test func hundredCardPushIsUnderFiveSeconds() async throws {
        let session = try await signIn(try #require(IntegrationEnvironment.current).a)
        defer { Task { try? await session.deleteAllDecks() } }
        let (facade, _, _) = try harness(session)
        let deck = try facade.saveDeck(draft("NFR-02", cards: 100))

        let started = ContinuousClock.now
        #expect(await facade.engine.syncNow())
        let elapsed = ContinuousClock.now - started
        #expect(deck.syncState == .synced)
        #expect(elapsed <= .seconds(5), "100-card push took \(elapsed)")
    }

    /// NFR-07: account B reads none of account A's rows.
    @Test func otherAccountReadsNothing() async throws {
        let env = try #require(IntegrationEnvironment.current)
        let a = try await signIn(env.a)
        defer { Task { try? await a.deleteAllDecks() } }
        let (facade, _, _) = try harness(a)
        let deck = try facade.saveDeck(draft("Private", cards: 2))
        #expect(await facade.engine.syncNow())

        let b = try await signIn(env.b)
        let changes = try await b.remote.fetchChanges(since: nil)
        #expect(!changes.decks.contains { $0.id == deck.id })
        #expect(!changes.cards.contains { $0.deckId == deck.id })
        #expect(try await b.remote.fetchDeckSnapshot(id: deck.id) == nil)
    }

    /// NFR-09: offline edits → reconnect → local and remote counts match, no
    /// duplicates.
    @Test func offlineEditsConvergeAfterReconnect() async throws {
        let session = try await signIn(try #require(IntegrationEnvironment.current).a)
        defer { Task { try? await session.deleteAllDecks() } }
        let (facade, _, reachability) = try harness(session, reachable: false)

        let deck = try facade.saveDeck(draft("Offline", cards: 3))
        var edit = DeckDraft(deck: deck)
        edit.cards.removeFirst()
        edit.cards.append(CardDraft(prompt: "Added offline", answer: "A"))
        _ = try facade.saveDeck(edit)
        #expect(await !facade.engine.syncNow())

        reachability.isReachable = true
        #expect(await facade.engine.syncNow())
        let snapshot = try #require(try await session.remote.fetchDeckSnapshot(id: deck.id))
        let remoteLive = snapshot.cards.filter { $0.card.deletedAt == nil }
        #expect(remoteLive.count == deck.activeCards.count)
        #expect(Set(remoteLive.compactMap(\.card.id)).count == remoteLive.count)
        #expect(Set(remoteLive.compactMap(\.card.id)) == Set(deck.activeCards.map(\.id)))
    }
}

/// Reads the opt-in credentials; nil unless all six are set.
struct IntegrationEnvironment {
    struct Account {
        let email: String
        let password: String
    }

    let url: URL
    let key: String
    let a: Account
    let b: Account

    static let current: IntegrationEnvironment? = {
        let env = ProcessInfo.processInfo.environment
        guard let rawURL = env["SUPABASE_TEST_URL"], let url = URL(string: rawURL),
              let key = env["SUPABASE_TEST_KEY"],
              let emailA = env["SUPABASE_TEST_EMAIL_A"], let passwordA = env["SUPABASE_TEST_PASSWORD_A"],
              let emailB = env["SUPABASE_TEST_EMAIL_B"], let passwordB = env["SUPABASE_TEST_PASSWORD_B"]
        else { return nil }
        return IntegrationEnvironment(
            url: url, key: key,
            a: Account(email: emailA, password: passwordA),
            b: Account(email: emailB, password: passwordB)
        )
    }()
}
