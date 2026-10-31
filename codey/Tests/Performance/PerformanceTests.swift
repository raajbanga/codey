import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import codey

/// S3-F performance test cases (TC-P01…P07). Thresholds are the Sprint 3
/// performance NFRs; a scenario without one is measured for the bottleneck
/// discussion only. Run with scripts/perf-report.sh (Release, Simulator).
@MainActor
@Suite(.serialized, .tags(.performance), .enabled(if: Perf.isEnabled, "Set CODEY_PERF=1 to run performance tests"))
struct PerformanceTests {
    /// TC-P01: building a 10-question mixed quiz (QuestionPool + fetches) ≤ 50 ms.
    @Test func quizBuild() throws {
        let (context, _) = try PerfFixture.seededContext()
        let topic = try #require(try context.fetch(FetchDescriptor<Topic>(sortBy: [SortDescriptor(\.id)])).first)
        var nextSeed: UInt64 = 0
        let result = Perf.measure("quiz_build_10q", thresholdMS: 50, setUp: { nextSeed += 1; return nextSeed }) { seed in
            let quiz = QuizViewModel(topic: topic, mode: .mixed, context: context, generator: SeededGenerator(seed: seed))
            #expect(!quiz.questions.isEmpty)
        }
        #expect(result.p95 <= 50)
    }

    /// TC-P02: validating + persisting a 100-card deck through the facade ≤ 250 ms.
    @Test func deckSave100Cards() throws {
        let draft = PerfFixture.draft(cards: 100)
        let result = try Perf.measure("deck_save_100", thresholdMS: 250, setUp: {
            BackendFacade.localOnly(context: try TestSupport.inMemoryContext())
        }) { facade in
            let deck = try facade.saveDeck(draft)
            #expect(deck.activeCards.count == 100)
        }
        #expect(result.p95 <= 250)
    }

    /// TC-P03: a full 100-card study session stays under 150 MB. The gate is
    /// the footprint the session adds (growth_mb); the Simulator's absolute
    /// footprint (peak_mb) is reported too, but most of it is iOS framework
    /// pages (see growthMB). NFR-28's absolute check runs on a device.
    @Test func studySession100CardsMemory() throws {
        let result = try Perf.measure("study_session_100", setUp: { () -> (FlashcardDeck, ModelContext) in
            let (context, facade) = try PerfFixture.seededContext()
            return (try facade.saveDeck(PerfFixture.draft(cards: 100)), context)
        }) { state in
            let (deck, context) = state
            let session = StudySessionViewModel(deck: deck, start: .fresh(tierFilter: nil), context: context)
            var steps = 0
            while !session.isFinished, steps < 1000 {
                session.toggleReveal()
                session.rate(.easy)
                steps += 1
            }
            #expect(session.isFinished)
        }
        #expect(result.growthMB <= 150)
    }

    /// TC-P04: launch-time seeding of the bundled question bank (decode +
    /// upsert into an empty store). Informational: the largest launch cost.
    @Test func dataSeederCold() throws {
        _ = try Perf.measure("seed_question_bank", setUp: { try TestSupport.inMemoryContext() }) { context in
            try DataSeeder.seed(context: context, bank: QuestionBankLoader.loadBank())
        }
    }

    /// TC-P05: seeding the starter decks (every card through FlashcardFactory).
    @Test func starterDeckSeed() throws {
        _ = try Perf.measure("seed_starter_decks", setUp: { () -> ModelContext in
            let context = try TestSupport.inMemoryContext()
            try DataSeeder.seed(context: context, bank: QuestionBankLoader.loadBank())
            return context
        }) { context in
            _ = try StarterDeckLoader.seed(context: context)
        }
    }

    /// TC-P06: first render of a card with an 80-line Swift snippet
    /// (Textual markdown + Prism highlighting) ≤ 100 ms.
    @Test func highlight80LineSnippet() throws {
        let snippet = CodeSnippet(language: .swift, source: PerfFixture.snippet(lines: ModelValidator.Limits.snippetMaxLines))
        let result = Perf.measure("highlight_80_lines", thresholdMS: 100, setUp: { () }) { _ in
            let renderer = ImageRenderer(content: CardMarkdownView(markdown: "What does this print?", snippet: snippet).frame(width: 390))
            #expect(renderer.uiImage != nil)
        }
        #expect(result.p95 <= 100)
    }

    /// TC-P07: pushing a 100-card deck against the in-memory backend with a
    /// 50 ms round trip per request (the live variant is
    /// SupabaseIntegrationTests.hundredCardPushIsUnderFiveSeconds) ≤ 5 s.
    @Test func syncPush100CardsMockRTT() async throws {
        let result = try await Perf.measureAsync("sync_push_100_mock50ms", thresholdMS: 5000, setUp: { () -> (BackendFacade, FlashcardDeck) in
            let context = try TestSupport.inMemoryContext()
            let suite = UserDefaults(suiteName: "codey-perf-\(UUID().uuidString)")!
            let facade = BackendFacade(
                context: context,
                auth: MockAuth(user: SyncHarness.alice),
                remote: LatencyRemoteStore(MockRemoteStore(), roundTrip: .milliseconds(50)),
                reachability: MockReachability(),
                cursors: SyncCursorStore(defaults: suite),
                weeklyXP: WeeklyXPStore(defaults: suite),
                groupCache: GroupCache(defaults: suite),
                sleep: { _ in throw CancellationError() }
            )
            return (facade, try facade.saveDeck(PerfFixture.draft(cards: 100)))
        }) { state in
            let (facade, deck) = state
            #expect(await facade.engine.syncNow())
            #expect(deck.syncState == .synced)
        }
        #expect(result.p95 <= 5000)
    }
}

/// Wraps a RemoteDeckStore and waits a fixed round trip before every call,
/// so mock sync timings reflect request count (the real bottleneck), not
/// in-memory speed.
@MainActor
final class LatencyRemoteStore: RemoteDeckStore {
    private let base: MockRemoteStore
    private let roundTrip: Duration

    init(_ base: MockRemoteStore, roundTrip: Duration) {
        self.base = base
        self.roundTrip = roundTrip
    }

    private func wait() async throws { try await Task.sleep(for: roundTrip) }

    func upsertDecks(_ decks: [DeckPayload]) async throws -> [UUID: Date] { try await wait(); return try await base.upsertDecks(decks) }
    func upsertCards(_ cards: [RemoteCard]) async throws { try await wait(); try await base.upsertCards(cards) }
    func fetchChanges(since cursor: Date?) async throws -> RemoteChanges { try await wait(); return try await base.fetchChanges(since: cursor) }
    func fetchDeckVersions(ids: [UUID]) async throws -> [UUID: Date] { try await wait(); return try await base.fetchDeckVersions(ids: ids) }
    func fetchDeckSnapshot(id: UUID) async throws -> RemoteDeckSnapshot? { try await wait(); return try await base.fetchDeckSnapshot(id: id) }
    func fetchProfile() async throws -> ProfilePayload? { try await wait(); return try await base.fetchProfile() }
    func upsertProfile(_ profile: ProfilePayload) async throws { try await wait(); try await base.upsertProfile(profile) }
    func appendSyncLog(_ entries: [SyncLogEntry]) async throws { try await wait(); try await base.appendSyncLog(entries) }
    func submitFeedback(_ report: FeedbackReportPayload) async throws { try await wait(); try await base.submitFeedback(report) }
    func fetchGroups() async throws -> [GroupSummary] { try await wait(); return try await base.fetchGroups() }
    func createGroup(id: UUID, name: String) async throws -> GroupSummary { try await wait(); return try await base.createGroup(id: id, name: name) }
    func joinGroup(code: String) async throws -> GroupSummary { try await wait(); return try await base.joinGroup(code: code) }
    func leaveGroup(id: UUID) async throws { try await wait(); try await base.leaveGroup(id: id) }
    func fetchLeaderboard(groupID: UUID) async throws -> [LeaderboardEntry] { try await wait(); return try await base.fetchLeaderboard(groupID: groupID) }
    func upsertWeeklyXP(weekStart: String, xp: Int) async throws { try await wait(); try await base.upsertWeeklyXP(weekStart: weekStart, xp: xp) }
}

/// TC-P08 fixture (Activity 9_2): writes 5 user decks of 50 cards into the
/// app's real on-disk store and marks onboarding done, so the launches that
/// scripts/perf-launch.sh times open a realistic store. The unit tests are
/// hosted in the app, so this runs inside the app's own container. Opt-in
/// (CODEY_PERF_SEED=1); safe to repeat, it only adds missing decks.
@MainActor
@Suite(.serialized, .tags(.performance), .enabled(if: ProcessInfo.processInfo.environment["CODEY_PERF_SEED"] == "1", "Set CODEY_PERF_SEED=1 to seed the launch store"))
struct LaunchFixtureSeed {
    static let userDecks = 5
    static let cardsPerDeck = 50

    @Test func seedLaunchStore() throws {
        let container = try ModelContainerFactory.make()
        let context = container.mainContext
        try DataSeeder.seed(context: context, bank: QuestionBankLoader.loadBank())
        _ = try StarterDeckLoader.seed(context: context)
        let existing = Set(try context.fetch(FetchDescriptor<FlashcardDeck>()).map(\.title))
        let facade = BackendFacade.localOnly(context: context)
        for n in 1...Self.userDecks where !existing.contains("Launch deck \(n)") {
            _ = try facade.saveDeck(PerfFixture.draft(title: "Launch deck \(n)", cards: Self.cardsPerDeck))
        }
        try context.save()
        UserDefaults.standard.set(true, forKey: OnboardingView.completedKey)
        let titles = try context.fetch(FetchDescriptor<FlashcardDeck>()).map(\.title)
        #expect(titles.filter { $0.hasPrefix("Launch deck") }.count == Self.userDecks)
    }
}
