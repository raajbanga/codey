import Foundation
import Observation
import SwiftData
import UIKit
import os

/// Façade (§9.4): everything the UI ever calls for auth, deck storage, and
/// sync. Saves go to SwiftData FIRST (FR-44) and are queued; the SyncEngine
/// pushes them when signed in and online. Without backend keys (or in UI
/// tests) auth/remote are nil and the app is local-only.
@MainActor
@Observable
final class BackendFacade: DeckBackend {
    private(set) var authState: AuthState = .signedOut
    private(set) var pendingCount = 0

    let engine: SyncEngine
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let auth: (any AuthProviding)?
    @ObservationIgnored private let remote: (any RemoteDeckStore)?
    @ObservationIgnored private let cursors: SyncCursorStore
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var authTask: Task<Void, Never>?
    @ObservationIgnored private var started = false

    init(
        context: ModelContext,
        auth: (any AuthProviding)?,
        remote: (any RemoteDeckStore)?,
        reachability: any Reachability,
        cursors: SyncCursorStore = SyncCursorStore(),
        deviceID: String? = nil,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.context = context
        self.auth = auth
        self.remote = remote
        self.cursors = cursors
        self.now = now
        weak let weakAuth = auth
        engine = SyncEngine(
            context: context, remote: remote, reachability: reachability, cursors: cursors,
            deviceID: deviceID, now: now, sleep: sleep, currentUserID: { weakAuth?.currentUserID() }
        )
        authState = auth?.currentUser().map(AuthState.signedIn) ?? .signedOut
        refreshPendingCount()
        engine.onCycleFinished = { [weak self] in self?.refreshPendingCount() }
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

    var lastSyncedAt: Date? { engine.lastSyncedAt ?? currentUser.flatMap { cursors.lastSyncedAt(for: $0.id) } }

    private var queue: SyncQueue { SyncQueue(context: context, now: now) }
    private var store: SwiftDataService { SwiftDataService(context: context, now: now) }
    private var userID: UUID? { currentUser?.id }

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
    }

    func appDidBecomeActive() {
        engine.requestSync(after: .zero)
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
        auth?.handle(url) ?? false
    }

    /// Syncing → LocallyPersisted; persisted Drafting → LocallyPersisted (9.2).
    func recoverDecks() {
        let decks = (try? context.fetch(FetchDescriptor<FlashcardDeck>())) ?? []
        let recovered = decks.filter { $0.recoverAfterLaunch() }
        guard !recovered.isEmpty else { return }
        for deck in recovered where !queue.hasPending(.deck, id: deck.id) {
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
            cursors.setCursor(nil, for: signedOutUser)
        }
        authState = .signedOut
        refreshPendingCount()
        engine.start()
    }

    /// Unsynced changes the sign-out dialog warns about.
    var unsyncedChangeCount: Int { queue.pendingCount(ownerId: userID) }

    // MARK: Decks (DeckBackend)

    /// Edit → save (Fig. 7) only when the draft changed something, so an
    /// unchanged save neither bumps updatedAt nor queues a push.
    func saveDeck(_ draft: DeckDraft) throws -> FlashcardDeck {
        let result: DraftSaveResult
        do {
            result = try store.apply(draft, ownerId: userID)
        } catch {
            context.rollback()
            throw error
        }
        let deck = result.deck
        if result.deckChanged {
            deck.editAndSave()
            try queue.enqueue(.deck, id: deck.id, op: .upsert, ownerId: deck.ownerId)
            for id in result.changedCardIDs {
                let card = try? store.fetchCard(id: id)
                try queue.enqueue(.card, id: id, op: SyncOperationKind(deletedAt: card?.deletedAt), ownerId: deck.ownerId)
            }
            try queue.remove(.card, ids: result.hardDeletedCardIDs)
        } else if deck.syncState == .drafting {
            deck.save()
        }
        // The first saved user deck earns a badge (FR-35).
        try BadgeEvaluator.award(context: context)
        try persist()
        return deck
    }

    func deleteDeck(_ deck: FlashcardDeck) throws {
        if let reason = deck.deleteBlockedReason {
            throw DeckBackendError.deleteNotAllowed(reason)
        }
        try queue.remove(.card, ids: deck.cards.map(\.id))
        if deck.hasEverSynced {
            deck.delete()
            try queue.enqueue(.deck, id: deck.id, op: .delete, ownerId: deck.ownerId)
        } else {
            try queue.remove(.deck, ids: [deck.id])
            context.delete(deck)
        }
        try persist()
    }

    /// FR-13 outside the builder.
    func deleteCard(_ card: Flashcard) throws {
        guard let deck = card.deck, deck.canEdit else { throw DeckBackendError.notEditable }
        deck.edit()
        if deck.hasEverSynced {
            card.deletedAt = now()
            card.updatedAt = now()
            try queue.enqueue(.card, id: card.id, op: .delete, ownerId: deck.ownerId)
        } else {
            try queue.remove(.card, ids: [card.id])
            context.delete(card)
        }
        deck.save()
        try queue.enqueue(.deck, id: deck.id, op: .upsert, ownerId: deck.ownerId)
        try persist()
    }

    func setHidden(_ hidden: Bool, deck: FlashcardDeck) throws {
        guard deck.origin == .starter else { return }
        deck.isHidden = hidden
        try context.save()
    }

    /// FR-04: saves the name and avatar locally and, when signed in, queues
    /// a profile push. A queued profile operation makes the local values win
    /// the next merge (last write wins). Throws the validator's FieldError.
    func updateProfile(displayName: String, avatarId: String?) throws {
        if let error = ModelValidator().validateDisplayName(displayName).first { throw error }
        let profile = DataSeeder.ensureProfile(context: context)
        profile.username = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.avatarId = avatarId.flatMap { ProfileAvatar.symbols.contains($0) ? $0 : nil }
        if let userID {
            try queue.enqueue(.profile, id: profile.id, op: .upsert, ownerId: userID)
        }
        try persist()
    }

    /// FR-49: sends a UI/UX issue report. Signed-in only (RLS ties the row
    /// to the account). Not queued: on failure the form keeps the text and
    /// shows the error, so the user can retry when back online.
    func submitFeedback(_ text: String) async throws {
        guard let remote, currentUser != nil else { throw FeedbackError.signInRequired }
        if let error = ModelValidator().validateFeedback(text).first { throw error }
        try await remote.submitFeedback(FeedbackReportPayload(
            id: UUID(),
            description: text.trimmingCharacters(in: .whitespacesAndNewlines),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            osVersion: UIDevice.current.systemVersion
        ))
    }

    /// "Reset progress" writes XP 0 explicitly instead of max-merging (D10).
    func didResetProgress() {
        guard let userID else { return }
        let profile = DataSeeder.ensureProfile(context: context)
        try? queue.enqueue(.profile, id: profile.id, op: .upsert, ownerId: userID)
        try? persist()
    }

    // MARK: Sync

    func syncPending() async {
        await engine.syncNow()
    }

    func refreshPendingCount() {
        pendingCount = queue.pendingCount(ownerId: userID)
    }

    // MARK: Private

    private func saveLoggingErrors() {
        do { try context.save() } catch { Logger.sync.error("Save failed: \(String(describing: error))") }
    }

    private func persist() throws {
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
        for deck in decks {
            deck.ownerId = ownerId
            if deck.syncState == .synced { deck.editAndSave() }
            guard deck.deletedAt == nil || deck.hasEverSynced else { continue }
            if !queue.hasPending(.deck, id: deck.id) {
                try queue.enqueue(.deck, id: deck.id, op: SyncOperationKind(deletedAt: deck.deletedAt), ownerId: ownerId)
            }
            for card in deck.cards where !queue.hasPending(.card, id: card.id) {
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

/// FR-49 failures the form explains.
enum FeedbackError: LocalizedError {
    case signInRequired

    var errorDescription: String? {
        switch self {
        case .signInRequired: "Sign in to send a report."
        }
    }
}
