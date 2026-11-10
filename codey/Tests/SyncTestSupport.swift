import Foundation
import SwiftData
import UIKit
@testable import codey

/// In-memory stand-in for the Supabase tables (no network). Mimics the
/// server: a trigger-set server_updated_at on every write (a fake clock that
/// ticks 1 s per write) and one owner (RLS is covered by the SQL checks).
@MainActor
final class MockRemoteStore: RemoteDeckStore {
    enum Failure: Error { case offline }

    private(set) var decks: [UUID: DeckPayload] = [:]
    private(set) var cards: [UUID: RemoteCard] = [:]
    private(set) var cardServerTimes: [UUID: Date] = [:]
    var profile: ProfilePayload? = ProfilePayload(displayName: "Remote Name", avatarId: nil, totalXP: 0)
    private(set) var log: [SyncLogEntry] = []
    /// Every call, by name, in order.
    private(set) var requests: [String] = []
    /// When true, every call throws (network drop / timeout).
    var isOffline = false

    private var clock = Date(timeIntervalSince1970: 1_900_000_000)

    private func tick() -> Date {
        clock = clock.addingTimeInterval(1)
        return clock
    }

    private func record(_ name: String) throws {
        requests.append(name)
        if isOffline { throw Failure.offline }
    }

    func upsertDecks(_ payloads: [DeckPayload]) async throws -> [UUID: Date] {
        try record("upsertDecks")
        var versions: [UUID: Date] = [:]
        for var deck in payloads {
            deck.serverUpdatedAt = tick()
            decks[deck.id] = deck
            versions[deck.id] = deck.serverUpdatedAt
        }
        return versions
    }

    func upsertCards(_ payloads: [RemoteCard]) async throws {
        try record("upsertCards")
        for var card in payloads {
            guard let id = card.card.id else { continue }
            card.card.masteryScore = nil  // no column remotely
            cards[id] = card
            cardServerTimes[id] = tick()
        }
    }

    func fetchChanges(since cursor: Date?) async throws -> RemoteChanges {
        try record("fetchChanges")
        let since = cursor ?? .distantPast
        let changedDecks = decks.values.filter { ($0.serverUpdatedAt ?? .distantPast) > since }
        let changedCards = cards.values.filter { (cardServerTimes[$0.card.id!] ?? .distantPast) > since }
        let cursor = (changedDecks.compactMap(\.serverUpdatedAt) + changedCards.compactMap { cardServerTimes[$0.card.id!] }).max()
        return RemoteChanges(decks: changedDecks, cards: changedCards, cursor: cursor)
    }

    func fetchDeckVersions(ids: [UUID]) async throws -> [UUID: Date] {
        try record("fetchDeckVersions")
        return Dictionary(uniqueKeysWithValues: ids.compactMap { id in decks[id]?.serverUpdatedAt.map { (id, $0) } })
    }

    func fetchDeckSnapshot(id: UUID) async throws -> RemoteDeckSnapshot? {
        try record("fetchDeckSnapshot")
        guard let deck = decks[id] else { return nil }
        return RemoteDeckSnapshot(deck: deck, cards: cards.values.filter { $0.deckId == id })
    }

    func fetchProfile() async throws -> ProfilePayload? {
        try record("fetchProfile")
        return profile
    }

    func upsertProfile(_ payload: ProfilePayload) async throws {
        try record("upsertProfile")
        profile = payload
    }

    func appendSyncLog(_ entries: [SyncLogEntry]) async throws {
        try record("appendSyncLog")
        log += entries
    }

    private(set) var feedback: [FeedbackReportPayload] = []

    func submitFeedback(_ report: FeedbackReportPayload) async throws {
        try record("submitFeedback")
        feedback.append(report)
    }

    // MARK: Groups (S3-D)

    private(set) var groups: [UUID: GroupSummary] = [:]
    /// group id → member ids.
    private(set) var members: [UUID: Set<UUID>] = [:]
    /// user id → XP this week (max-merged like the server).
    private(set) var weeklyXP: [UUID: Int] = [:]
    var me = SyncHarness.alice.id
    var displayNames: [UUID: String] = [:]
    var nextInviteCode = "ABC234"

    func fetchGroups() async throws -> [GroupSummary] {
        try record("fetchGroups")
        return groups.values.filter { members[$0.id]?.contains(me) == true }.sorted { $0.name < $1.name }
    }

    func createGroup(id: UUID, name: String) async throws -> GroupSummary {
        try record("createGroup")
        let group = GroupSummary(id: id, name: name, inviteCode: nextInviteCode)
        groups[id] = group
        members[id, default: []].insert(me)
        return group
    }

    func joinGroup(code: String) async throws -> GroupSummary {
        try record("joinGroup")
        guard let group = groups.values.first(where: { $0.inviteCode == code }) else { throw GroupError.invalidCode }
        members[group.id, default: []].insert(me)
        return group
    }

    func leaveGroup(id: UUID) async throws {
        try record("leaveGroup")
        members[id]?.remove(me)
    }

    func fetchLeaderboard(groupID: UUID) async throws -> [LeaderboardEntry] {
        try record("fetchLeaderboard")
        guard members[groupID]?.contains(me) == true else { return [] }
        return (members[groupID] ?? []).map { user in
            LeaderboardEntry(userId: user, displayName: displayNames[user] ?? "User", avatarId: nil, xp: weeklyXP[user] ?? 0)
        }
    }

    func upsertWeeklyXP(weekStart: String, xp: Int) async throws {
        try record("upsertWeeklyXP")
        weeklyXP[me] = max(weeklyXP[me] ?? 0, xp)
    }

    // MARK: Study progress (FR-61), merged like the SQL triggers

    private(set) var cardProgress: [UUID: CardProgressPayload] = [:]
    private(set) var questionProgress: [String: QuestionProgressPayload] = [:]
    private(set) var topicProgress: [String: TopicProgressPayload] = [:]
    private var progressTimes: [String: Date] = [:]

    func fetchProgressChanges(since cursor: Date?) async throws -> RemoteProgressChanges {
        try record("fetchProgressChanges")
        let since = cursor ?? .distantPast
        func changed(_ key: String) -> Bool { (progressTimes[key] ?? .distantPast) > since }
        let batch = ProgressBatch(
            cards: cardProgress.values.filter { changed("c:\($0.cardId)") },
            questions: questionProgress.values.filter { changed("q:\($0.questionId)") },
            topics: topicProgress.values.filter { changed("t:\($0.topicId)") }
        )
        let keys = batch.cards.map { "c:\($0.cardId)" } + batch.questions.map { "q:\($0.questionId)" } + batch.topics.map { "t:\($0.topicId)" }
        return RemoteProgressChanges(progress: batch, cursor: keys.compactMap { progressTimes[$0] }.max())
    }

    private(set) var pushedProgress: [ProgressBatch] = []

    func upsertProgress(_ batch: ProgressBatch) async throws {
        try record("upsertProgress")
        pushedProgress.append(batch)
        for row in batch.cards { storeCardProgress(row) }
        for row in batch.questions { storeQuestionProgress(row) }
        for row in batch.topics { storeTopicProgress(row) }
    }

    private func storeCardProgress(_ row: CardProgressPayload) {
        if let old = cardProgress[row.cardId], row.lastReviewedAt <= old.lastReviewedAt { return }
        cardProgress[row.cardId] = row
        progressTimes["c:\(row.cardId)"] = tick()
    }

    private func storeQuestionProgress(_ row: QuestionProgressPayload) {
        if let old = questionProgress[row.questionId], row.lastAnsweredAt <= old.lastAnsweredAt { return }
        questionProgress[row.questionId] = row
        progressTimes["q:\(row.questionId)"] = tick()
    }

    private func storeTopicProgress(_ row: TopicProgressPayload) {
        var merged = row
        if let old = topicProgress[row.topicId] {
            merged.mediumUnlockedAt = ProgressSync.earliest(old.mediumUnlockedAt, row.mediumUnlockedAt)
            merged.hardUnlockedAt = ProgressSync.earliest(old.hardUnlockedAt, row.hardUnlockedAt)
            if merged == old { return }
        }
        topicProgress[row.topicId] = merged
        progressTimes["t:\(row.topicId)"] = tick()
    }

    /// Progress written by another device.
    func otherDeviceUpsert(progress batch: ProgressBatch) {
        batch.cards.forEach(storeCardProgress)
        batch.questions.forEach(storeQuestionProgress)
        batch.topics.forEach(storeTopicProgress)
    }

    /// Another user's membership and XP, as if they'd joined elsewhere.
    func addMember(_ user: UUID, name: String, xp: Int, to groupID: UUID) {
        members[groupID, default: []].insert(user)
        displayNames[user] = name
        weeklyXP[user] = xp
    }

    // MARK: "Another device" writes

    func otherDeviceUpsert(deck: DeckPayload) {
        var deck = deck
        deck.serverUpdatedAt = tick()
        decks[deck.id] = deck
    }

    func otherDeviceUpsert(card: FlashcardPayload, deckId: UUID) {
        cards[card.id!] = RemoteCard(deckId: deckId, card: card)
        cardServerTimes[card.id!] = tick()
    }

    func liveCards(deckId: UUID) -> [RemoteCard] {
        cards.values.filter { $0.deckId == deckId && $0.card.deletedAt == nil }
    }
}

@MainActor
final class MockAuth: AuthProviding {
    var user: AppUser?
    /// What signIn returns (nil = the user cancelled).
    var nextSignIn: AppUser?
    private(set) var signOutCount = 0
    private var continuations: [AsyncStream<AppUser?>.Continuation] = []

    init(user: AppUser? = nil) {
        self.user = user
    }

    func signIn(presenting viewController: UIViewController) async throws -> AppUser? {
        user = nextSignIn
        return nextSignIn
    }

    func signOut() async {
        signOutCount += 1
        user = nil
        continuations.forEach { $0.yield(nil) }
    }

    func currentUser() -> AppUser? { user }
    func currentUserID() -> UUID? { user?.id }

    func authStateStream() -> AsyncStream<AppUser?> {
        let (stream, continuation) = AsyncStream<AppUser?>.makeStream()
        continuations.append(continuation)
        return stream
    }

    func handle(_ url: URL) -> Bool { false }
}

@MainActor
final class MockReachability: Reachability {
    var isReachable: Bool
    private var continuations: [AsyncStream<Bool>.Continuation] = []

    init(isReachable: Bool = true) {
        self.isReachable = isReachable
    }

    func changes() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        continuations.append(continuation)
        return stream
    }

    func set(_ reachable: Bool) {
        isReachable = reachable
        continuations.forEach { $0.yield(reachable) }
    }
}

/// Records backoff/debounce sleeps without waiting; cancels the sleeping
/// task so tests drive every sync explicitly.
@MainActor
final class SleepRecorder {
    private(set) var durations: [Duration] = []

    var sleep: (Duration) async throws -> Void {
        { [weak self] duration in
            await MainActor.run { self?.durations.append(duration) }
            throw CancellationError()
        }
    }
}

/// One "device": its own store, plus a facade wired to shared mocks.
@MainActor
struct SyncHarness {
    nonisolated static let alice = AppUser(id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!, email: "a@example.com", displayName: "Alice")

    let context: ModelContext
    let facade: BackendFacade
    let auth: MockAuth
    let remote: MockRemoteStore
    let reachability: MockReachability
    let sleeper: SleepRecorder
    let weeklyXP: WeeklyXPStore

    init(
        user: AppUser? = SyncHarness.alice,
        remote: MockRemoteStore? = nil,
        reachable: Bool = true,
        now: @escaping () -> Date = Date.init
    ) throws {
        context = try TestSupport.inMemoryContext()
        auth = MockAuth(user: user)
        self.remote = remote ?? MockRemoteStore()
        reachability = MockReachability(isReachable: reachable)
        sleeper = SleepRecorder()
        let suite = UserDefaults(suiteName: "codey-tests-\(UUID().uuidString)")!
        weeklyXP = WeeklyXPStore(defaults: suite)
        facade = BackendFacade(
            context: context,
            auth: auth,
            remote: self.remote,
            reachability: reachability,
            cursors: SyncCursorStore(defaults: suite),
            weeklyXP: weeklyXP,
            groupCache: GroupCache(defaults: suite),
            deviceID: "test-device",
            now: now,
            sleep: sleeper.sleep
        )
    }

    var engine: SyncEngine { facade.engine }
    var queue: SyncQueue { SyncQueue(context: context) }

    /// Saves a new user deck through the facade.
    @discardableResult
    func saveNewDeck(title: String = "Swift", prompts: [String] = ["Q1", "Q2"]) throws -> FlashcardDeck {
        var draft = DeckDraft.new(topicId: "topic-data-structures")
        draft.title = title
        draft.cards = prompts.map { CardDraft(prompt: $0, answer: "A") }
        return try facade.saveDeck(draft)
    }

    func decks() throws -> [FlashcardDeck] {
        try context.fetch(FetchDescriptor<FlashcardDeck>())
    }
}
