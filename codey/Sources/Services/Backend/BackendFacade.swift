import Foundation
import Observation
import SwiftData
import UIKit
import os

// MARK: - [Pattern: Facade] Facade (core: lifecycle, auth, sync)
/// Façade (§9.4): everything the UI ever calls for auth, deck storage, and
/// sync. Saves go to SwiftData FIRST (FR-44) and are queued; the SyncEngine
/// pushes them when signed in and online. Without backend keys (or in UI
/// tests) auth/remote are nil and the app is local-only.
///
/// One type, split by concern (R8 file-size limit): this file holds state,
/// lifecycle, auth and sync; decks, profile/feedback and groups live in
/// BackendFacade+Decks/+Profile/+Groups.swift.
@MainActor
@Observable
final class BackendFacade: DeckBackend {
    private(set) var authState: AuthState = .signedOut {
        didSet { if authState.user?.id != oldValue.user?.id { refreshLastSyncedAt() } }
    }
    private(set) var pendingCount = 0
    /// This account's last good sync. Kept as state (refreshed on account
    /// change and after each cycle), so views don't read UserDefaults.
    private(set) var lastSyncedAt: Date?

    let engine: SyncEngine
    // Internal, not private: the BackendFacade+*.swift extensions use them.
    @ObservationIgnored let context: ModelContext
    @ObservationIgnored private let auth: (any AuthProviding)?
    @ObservationIgnored let remote: (any RemoteDeckStore)?
    @ObservationIgnored private let cursors: SyncCursorStore
    @ObservationIgnored let groupCache: GroupCache
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored let queue: SyncQueue
    @ObservationIgnored let store: SwiftDataService
    @ObservationIgnored private var authTask: Task<Void, Never>?
    @ObservationIgnored private var started = false
    /// When content was last checked, so becoming active doesn't refetch
    /// every time.
    @ObservationIgnored private var contentCheckedAt: Date?

    init(
        context: ModelContext,
        auth: (any AuthProviding)?,
        remote: (any RemoteDeckStore)?,
        reachability: any Reachability,
        cursors: SyncCursorStore = SyncCursorStore(),
        weeklyXP: WeeklyXPStore = WeeklyXPStore(),
        groupCache: GroupCache = GroupCache(),
        deviceID: String? = nil,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.context = context
        self.auth = auth
        self.remote = remote
        self.cursors = cursors
        self.groupCache = groupCache
        self.now = now
        queue = SyncQueue(context: context, now: now)
        store = SwiftDataService(context: context, now: now)
        weak let weakAuth = auth
        engine = SyncEngine(
            context: context, remote: remote, reachability: reachability, cursors: cursors,
            weeklyXP: weeklyXP, deviceID: deviceID, now: now, sleep: sleep, currentUserID: { weakAuth?.currentUserID() }
        )
        authState = auth?.currentUser().map(AuthState.signedIn) ?? .signedOut
        refreshPendingCount()
        refreshLastSyncedAt()
        engine.onCycleFinished = { [weak self] in
            self?.refreshPendingCount()
            self?.refreshLastSyncedAt()
        }
    }

    /// The app's facade: Supabase-backed when the build has backend keys,
    /// otherwise local-only.
    static func live(context: ModelContext) -> BackendFacade {
        let services = SupabaseServices.make()
        return BackendFacade(
            context: context,
            auth: services?.auth,
            remote: services?.remote,
            reachability: NetworkMonitor(),
            deviceID: UIDevice.current.identifierForVendor?.uuidString
        )
    }

    /// Guest-only facade: previews, UI tests, and builds without backend keys.
    static func localOnly(context: ModelContext) -> BackendFacade {
        BackendFacade(context: context, auth: nil, remote: nil, reachability: NetworkMonitor())
    }

    /// Whether sign-in is possible in this build.
    var isSignInAvailable: Bool { auth != nil }

    var currentUser: AppUser? { authState.user }

    var userID: UUID? { currentUser?.id }

    // MARK: Lifecycle

    /// Launch: crash recovery, auth observation, reachability, first sync.
    func start() {
        guard !started else { return }
        started = true
        recoverDecks()
        if let auth {
            let stream = auth.authStateStream()
            authTask = Task { [weak self] in
                for await user in stream {
                    guard let self, authState != .signingIn else { continue }
                    authState = user.map(AuthState.signedIn) ?? .signedOut
                }
            }
        }
        engine.start()
        engine.requestSync(after: .zero)
        Task { await refreshContent() }
    }

    func appDidBecomeActive() {
        engine.requestSync(after: .zero)
        Task { await refreshContent() }
    }

    /// Downloads the content from Supabase (signed in or not) and, when it
    /// changed, caches and seeds it: new questions, exercises and decks
    /// reach the app without an update. Offline or failing, the app keeps
    /// what it has (the last download, else the bundle). At most every ten
    /// minutes unless forced.
    func refreshContent(force: Bool = false) async {
        guard let remote, !AppLaunchOptions.usesInMemoryStore else { return }
        if !force, let last = contentCheckedAt, now().timeIntervalSince(last) < 600 { return }
        contentCheckedAt = now()
        do {
            let files = try await remote.fetchContent()
            try ContentSeeder.apply(files, context: context)
        } catch {
            Logger.seeding.error("Content refresh failed: \(String(describing: error))")
        }
    }

    /// FR-61: study and quiz progress isn't queued, so push it when the app
    /// leaves the foreground (the end of most study sessions).
    func appDidEnterBackground() {
        engine.requestSync(after: .zero)
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
        auth?.handle(url) ?? false
    }

    /// Syncing → LocallyPersisted; persisted Drafting → LocallyPersisted (9.2).
    func recoverDecks() {
        let decks = (try? context.fetch(FetchDescriptor<FlashcardDeck>())) ?? []
        let recovered = decks.filter { $0.recoverAfterLaunch(at: now()) }
        guard !recovered.isEmpty else { return }
        let pending = (try? queue.pendingIDs(.deck)) ?? []
        for deck in recovered where !pending.contains(deck.id) {
            try? queue.enqueue(.deck, id: deck.id, op: SyncOperationKind(deletedAt: deck.deletedAt), ownerId: deck.ownerId)
        }
        saveLoggingErrors()
        Logger.sync.notice("Recovered \(recovered.count) deck(s) after launch")
    }

    // MARK: Auth (FR-01, FR-03)

    /// `presenter` defaults to the top view controller.
    func signInWithGoogle(presenting presenter: UIViewController? = nil) async {
        guard let auth, let presenter = presenter ?? UIApplication.shared.topViewController else { return }
        authState = .signingIn
        do {
            guard let user = try await auth.signIn(presenting: presenter) else {
                authState = .signedOut
                return
            }
            try claimGuestDecks(for: user.id)
            authState = .signedIn(user)
            await engine.syncNow()
        } catch {
            Logger.auth.error("Sign-in failed: \(String(describing: error))")
            authState = .error("Couldn't sign in. Check your connection and try again.")
        }
    }

    /// FR-03. Removing (the default) deletes this account's decks from the
    /// device, so another account can't upload them later (O3).
    func signOut(removingLocalDecks: Bool) async {
        guard let auth else { return }
        let signedOutUser = userID
        engine.stop()
        await auth.signOut()
        if let signedOutUser {
            if removingLocalDecks {
                removeDecks(ownedBy: signedOutUser)
            }
            cursors.set(nil, .pullCursor, for: signedOutUser)
            // FR-61: the next sign-in pulls and pushes all progress again.
            cursors.set(nil, .progressCursor, for: signedOutUser)
            cursors.set(nil, .progressPushedAt, for: signedOutUser)
            cursors.set(nil, .historyPushedAt, for: signedOutUser)
        }
        groupCache.clear()
        authState = .signedOut
        refreshPendingCount()
        engine.start()
    }

    /// Unsynced changes the sign-out dialog warns about.
    var unsyncedChangeCount: Int { queue.pendingCount(ownerId: userID) }

    // MARK: Sync

    func syncPending() async {
        await engine.syncNow()
    }

    func refreshPendingCount() {
        pendingCount = queue.pendingCount(ownerId: userID)
    }

    private func refreshLastSyncedAt() {
        lastSyncedAt = currentUser.flatMap { cursors.date(.lastSyncedAt, for: $0.id) }
    }

    // MARK: Private

    private func saveLoggingErrors() {
        do { try context.save() } catch { Logger.sync.error("Save failed: \(String(describing: error))") }
    }

    /// Saves, refreshes the pending badge, and nudges the sync engine.
    func persist() throws {
        try context.save()
        refreshPendingCount()
        engine.requestSync()
    }

    /// First sign-in on a device: guest decks become the account's and are
    /// queued (decks from before sync existed had no operations yet).
    private func claimGuestDecks(for ownerId: UUID) throws {
        let user = DeckOrigin.user.rawValue
        let guest: UUID? = nil
        let decks = try context.fetch(FetchDescriptor<FlashcardDeck>(
            predicate: #Predicate { $0.originRaw == user && $0.ownerId == guest }
        ))
        try queue.claimGuestOperations(for: ownerId)
        let pendingDecks = try queue.pendingIDs(.deck)
        let pendingCards = try queue.pendingIDs(.card)
        for deck in decks {
            deck.ownerId = ownerId
            if deck.syncState == .synced { deck.editAndSave(at: now()) }
            guard deck.deletedAt == nil || deck.hasEverSynced else { continue }
            if !pendingDecks.contains(deck.id) {
                try queue.enqueue(.deck, id: deck.id, op: SyncOperationKind(deletedAt: deck.deletedAt), ownerId: ownerId)
            }
            for card in deck.cards where !pendingCards.contains(card.id) {
                try queue.enqueue(.card, id: card.id, op: SyncOperationKind(deletedAt: card.deletedAt), ownerId: ownerId)
            }
        }
        try context.save()
    }

    private func removeDecks(ownedBy ownerId: UUID) {
        let owner: UUID? = ownerId
        let decks = (try? context.fetch(FetchDescriptor<FlashcardDeck>(predicate: #Predicate { $0.ownerId == owner }))) ?? []
        for deck in decks {
            if let snapshot = try? StudyProgressSnapshot.fetch(deckId: deck.id, context: context) {
                context.delete(snapshot)
            }
            context.delete(deck)
        }
        try? queue.removeAll(ownerId: ownerId)
        saveLoggingErrors()
    }
}
