import Foundation
import Observation
import SwiftData
import os

/// Pushes the queue, pulls remote changes, and syncs the profile (FR-46,
/// FR-47, NFR-09). One cycle = push (with the conflict check) → pull → profile.
/// Failures back off exponentially (2, 4, 8 … 300 s); reconnecting resets the
/// backoff and syncs at once.
@MainActor
@Observable
final class SyncEngine {
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?
    private(set) var lastError: String?
    private(set) var consecutiveFailures = 0
    /// Called after every cycle, successful or not (the facade refreshes its
    /// pending count).
    @ObservationIgnored var onCycleFinished: (() -> Void)?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let remote: (any RemoteDeckStore)?
    @ObservationIgnored private let reachability: any Reachability
    @ObservationIgnored private let currentUserID: () -> UUID?
    @ObservationIgnored private let cursors: SyncCursorStore
    @ObservationIgnored private let deviceID: String?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sleep: (Duration) async throws -> Void
    @ObservationIgnored private var scheduled: Task<Void, Never>?
    @ObservationIgnored private var reachabilityTask: Task<Void, Never>?
    @ObservationIgnored private var rerunRequested = false

    /// Operations per push request; larger queues take several rounds.
    static let batchLimit = 500
    /// Re-pull this much before the cursor, in case a slow transaction
    /// committed a row with an earlier server timestamp. Applying is idempotent.
    static let pullOverlap: TimeInterval = 2

    private var queue: SyncQueue { SyncQueue(context: context, now: now) }
    private var store: SwiftDataService { SwiftDataService(context: context, now: now) }

    init(
        context: ModelContext,
        remote: (any RemoteDeckStore)?,
        reachability: any Reachability,
        cursors: SyncCursorStore = SyncCursorStore(),
        deviceID: String? = nil,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        currentUserID: @escaping () -> UUID?
    ) {
        self.context = context
        self.remote = remote
        self.reachability = reachability
        self.cursors = cursors
        self.deviceID = deviceID
        self.now = now
        self.sleep = sleep
        self.currentUserID = currentUserID
    }

    /// Delay before retry n (1-based): 2, 4, 8 … capped at 300 s.
    static func backoffDelay(afterFailures failures: Int) -> Duration {
        let exponent = min(max(failures, 1), 9)
        return .seconds(min(1 << exponent, 300))
    }

    /// Starts watching reachability: a reconnect syncs right away (NFR-09).
    func start() {
        guard reachabilityTask == nil else { return }
        let changes = reachability.changes()
        reachabilityTask = Task { [weak self] in
            for await reachable in changes where reachable {
                guard let self else { return }
                consecutiveFailures = 0
                await syncNow()
            }
        }
    }

    func stop() {
        reachabilityTask?.cancel()
        reachabilityTask = nil
        scheduled?.cancel()
        scheduled = nil
    }

    /// Debounced trigger (after saves). Replaces any pending trigger.
    func requestSync(after delay: Duration = .seconds(2)) {
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            if delay > .zero {
                do { try await self?.sleep(delay) } catch { return }
            }
            await self?.syncNow()
        }
    }

    var canSync: Bool {
        remote != nil && currentUserID() != nil && reachability.isReachable
    }

    /// Runs a full cycle now. Returns false if it couldn't run or failed.
    @discardableResult
    func syncNow() async -> Bool {
        guard let remote, let userID = currentUserID(), reachability.isReachable else { return false }
        guard !isSyncing else {
            rerunRequested = true
            return false
        }
        isSyncing = true
        defer {
            isSyncing = false
            onCycleFinished?()
        }

        repeat {
            rerunRequested = false
            do {
                try await push(remote: remote, userID: userID)
                try await pull(remote: remote, userID: userID)
                try await syncProfile(remote: remote, userID: userID)
                consecutiveFailures = 0
                lastError = nil
                lastSyncedAt = now()
                cursors.setLastSyncedAt(lastSyncedAt, for: userID)
            } catch {
                failCycle(error)
                return false
            }
        } while rerunRequested
        return true
    }

    // MARK: Push

    private func push(remote: any RemoteDeckStore, userID: UUID) async throws {
        for _ in 0..<20 {
            let operations = try queue.peekBatch(limit: Self.batchLimit, ownerId: userID).filter { $0.entity != .profile }
            guard !operations.isEmpty else { return }
            try await pushBatch(operations, remote: remote)
            if operations.count < Self.batchLimit { return }
        }
    }

    private func pushBatch(_ operations: [SyncOperation], remote: any RemoteDeckStore) async throws {
        let operationIDs = operations.map(\.id)
        var decks: [FlashcardDeck] = []
        var cardIDs: [UUID] = []
        var obsolete: [SyncOperation] = []
        var waiting: Set<UUID> = []

        for operation in operations where operation.entity == .deck {
            guard let deck = try store.fetch(id: operation.entityId), deck.origin == .user else {
                obsolete.append(operation)
                continue
            }
            if deck.syncState == .drafting {
                waiting.insert(deck.id)
                continue
            }
            if deck.syncState == .synced {
                deck.edit()
                deck.save()
            }
            decks.append(deck)
        }
        for operation in operations where operation.entity == .card {
            guard let card = try store.fetchCard(id: operation.entityId), let deck = card.deck, deck.origin == .user else {
                obsolete.append(operation)
                continue
            }
            if waiting.contains(deck.id) || deck.syncState == .drafting { continue }
            cardIDs.append(card.id)
        }
        try queue.markDone(obsolete)

        decks.forEach { $0.push() }
        try context.save()

        do {
            cardIDs += try await resolveConflicts(decks, remote: remote)
            let versions = try await remote.upsertDecks(decks.map { $0.toPayload() })
            let cards = Set(cardIDs).compactMap { try? store.fetchCard(id: $0) }.compactMap { card -> RemoteCard? in
                guard let deckID = card.deck?.id else { return nil }
                return RemoteCard(deckId: deckID, card: card.toPayload())
            }
            if !cards.isEmpty {
                try await remote.upsertCards(cards)
            }
            await appendLog(operationIDs: operationIDs, remote: remote)

            // Done with exactly the operations we sent; anything enqueued
            // while we were waiting stays queued.
            let sent = Set(operationIDs)
            try queue.markDone(try context.fetch(FetchDescriptor<SyncOperation>()).filter { sent.contains($0.id) })
            for deck in decks {
                deck.receive(.ack(serverUpdatedAt: versions[deck.id] ?? now()))
                if deck.deletedAt != nil {
                    // Fig. 7 final state: the delete reached the server.
                    store.delete(deck)
                } else if queue.hasPending(.deck, id: deck.id) {
                    deck.edit()
                    deck.save()
                }
            }
            try context.save()
        } catch {
            for deck in decks where deck.syncState == .syncing || deck.syncState == .conflict {
                if deck.syncState == .conflict { deck.resolve() } else { deck.receive(.networkFailure) }
            }
            let sent = Set(operationIDs)
            try? queue.markFailed(
                (try? context.fetch(FetchDescriptor<SyncOperation>()))?.filter { sent.contains($0.id) } ?? [],
                error: String(describing: error)
            )
            throw error
        }
    }

    /// Syncing → ConflictDetected when the remote deck changed since our last
    /// sync (its server_updated_at moved past ours) and ours is dirty, which it
    /// is (it's being pushed). Merges, resolves, and re-enters Syncing.
    /// Returns extra card ids to push.
    private func resolveConflicts(_ decks: [FlashcardDeck], remote: any RemoteDeckStore) async throws -> [UUID] {
        guard !decks.isEmpty else { return [] }
        let versions = try await remote.fetchDeckVersions(ids: decks.map(\.id))
        var extraCards: [UUID] = []
        for deck in decks {
            let remoteMoved = versions[deck.id].map { remoteVersion in
                deck.serverUpdatedAt.map { ConflictResolver.isLater(remoteVersion, than: $0) } ?? true
            } ?? false
            // A deck left in Conflict by a killed app merges again too.
            guard remoteMoved || deck.syncState == .conflict else { continue }
            deck.receive(.timestampMismatch)
            guard let snapshot = try await remote.fetchDeckSnapshot(id: deck.id) else {
                deck.resolve()
                deck.push()
                continue
            }
            let outcome = try ConflictResolver(context: context).merge(deck, with: snapshot)
            deck.resolve()
            deck.push()
            extraCards += outcome.cardsToPush
            Logger.sync.notice("Merged a conflicting deck (\(outcome.cardsTakenFromRemote.count) remote card changes)")
        }
        try context.save()
        return extraCards
    }

    private func appendLog(operationIDs: [UUID], remote: any RemoteDeckStore) async {
        let sent = Set(operationIDs)
        let entries = ((try? context.fetch(FetchDescriptor<SyncOperation>())) ?? [])
            .filter { sent.contains($0.id) }
            .map { SyncLogEntry(entity: $0.entity, entityId: $0.entityId, op: $0.op, clientTimestamp: $0.enqueuedAt, deviceId: deviceID) }
        guard !entries.isEmpty else { return }
        do {
            try await remote.appendSyncLog(entries)
        } catch {
            // The ledger is an audit aid (R2); a failed append doesn't undo the push.
            Logger.sync.error("sync_log append failed: \(String(describing: error))")
        }
    }

    // MARK: Pull

    private func pull(remote: any RemoteDeckStore, userID: UUID) async throws {
        let since = cursors.cursor(for: userID).map { $0.addingTimeInterval(-Self.pullOverlap) }
        let changes = try await remote.fetchChanges(since: since)
        let queue = queue
        try RemoteChangeApplier(context: context, now: now).apply(changes, ownerId: userID) { deck in
            deck.syncState == .synced && !queue.hasPending(.deck, id: deck.id)
        }
        try context.save()
        if let cursor = changes.cursor {
            cursors.setCursor(max(cursor, cursors.cursor(for: userID) ?? cursor), for: userID)
        }
    }

    // MARK: Profile (D10)

    /// total_xp = max(local, remote): XP only goes up, except an explicit
    /// "Reset progress" (a queued profile operation), which writes local as-is.
    /// display_name: last write wins; the app has no local name editor yet, so
    /// the remote name wins unless a profile operation is queued.
    private func syncProfile(remote: any RemoteDeckStore, userID: UUID) async throws {
        guard let remoteProfile = try await remote.fetchProfile() else { return }
        let profile = DataSeeder.ensureProfile(context: context)
        let operations = try queue.peekBatch(limit: Self.batchLimit, ownerId: userID).filter { $0.entity == .profile }
        let explicit = !operations.isEmpty

        let xp = explicit ? profile.totalXP : max(profile.totalXP, remoteProfile.totalXP)
        let name = explicit ? profile.username : remoteProfile.displayName
        profile.totalXP = xp
        profile.username = name
        try context.save()

        if remoteProfile.totalXP != xp || remoteProfile.displayName != name {
            try await remote.upsertProfile(ProfilePayload(displayName: name, avatarId: remoteProfile.avatarId, totalXP: xp))
        }
        try queue.markDone(operations)
    }

    // MARK: Failure

    private func failCycle(_ error: Error) {
        consecutiveFailures += 1
        lastError = (error as? LocalizedError)?.errorDescription ?? "Couldn't reach the server."
        Logger.sync.error("Sync failed (\(self.consecutiveFailures) in a row): \(String(describing: error))")
        requestSync(after: Self.backoffDelay(afterFailures: consecutiveFailures))
    }
}
