import Foundation
import SwiftData
import Testing
import UIKit
@testable import codey

/// SyncEngine + BackendFacade against mocks (no network): FR-44–48, NFR-02,
/// NFR-09.
@MainActor
struct SyncEngineTests {
    // MARK: Push

    @Test func pushSuccessMarksSyncedAndEmptiesTheQueue() async throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck(prompts: ["Q1", "Q2"])
        #expect(deck.syncState == .locallyPersisted)
        #expect(deck.ownerId == SyncHarness.alice.id)
        #expect(h.facade.pendingCount == 3)

        #expect(await h.engine.syncNow())
        #expect(deck.syncState == .synced)
        #expect(deck.lastSyncedAt != nil)
        #expect(deck.serverUpdatedAt == h.remote.decks[deck.id]?.serverUpdatedAt)
        #expect(h.remote.liveCards(deckId: deck.id).count == 2)
        #expect(h.facade.pendingCount == 0)
        #expect(h.remote.log.count == 3)
        #expect(h.remote.log.allSatisfy { $0.deviceId == "test-device" })
    }

    /// Save, ack and delete all read the facade's injected clock.
    @Test func stateTransitionsUseTheInjectedClock() async throws {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let h = try SyncHarness(now: { t })
        let deck = try h.saveNewDeck()
        #expect(deck.updatedAt == t)

        #expect(await h.engine.syncNow())
        #expect(deck.lastSyncedAt == t)

        try h.facade.deleteDeck(deck)
        #expect(deck.deletedAt == t)
    }

    @Test func pushTimeoutFallsBackToLocallyPersistedAndBacksOff() async throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck()
        h.remote.isOffline = true

        #expect(await !h.engine.syncNow())
        #expect(deck.syncState == .locallyPersisted)
        #expect(h.engine.consecutiveFailures == 1)
        #expect(h.engine.lastError != nil)
        #expect(h.queue.hasPending(.deck, id: deck.id))
        #expect(try h.queue.pendingOperation(.deck, id: deck.id)?.attempts == 1)
        // The retry is scheduled after the first backoff step.
        try await Task.sleep(for: .milliseconds(50))
        #expect(h.sleeper.durations.last == .seconds(2))

        h.remote.isOffline = false
        #expect(await h.engine.syncNow())
        #expect(deck.syncState == .synced)
        #expect(h.engine.consecutiveFailures == 0)
    }

    @Test func backoffDoublesUpToFiveMinutes() {
        let delays = (1...10).map { SyncEngine.backoffDelay(afterFailures: $0) }
        #expect(delays == [2, 4, 8, 16, 32, 64, 128, 256, 300, 300].map { Duration.seconds($0) })
    }

    /// FR-44: saving offline is local-first and never touches the network.
    @Test func offlineSaveNeverTouchesTheNetwork() async throws {
        let h = try SyncHarness(reachable: false)
        let deck = try h.saveNewDeck()
        #expect(await !h.engine.syncNow())
        #expect(h.remote.requests.isEmpty)
        #expect(deck.syncState == .locallyPersisted)
        #expect(try h.decks().count == 1)
    }

    /// Guests queue too; nothing is pushed until sign-in.
    @Test func signedOutSaveIsQueuedButNotPushed() async throws {
        let h = try SyncHarness(user: nil)
        let deck = try h.saveNewDeck()
        #expect(deck.ownerId == nil)
        #expect(await !h.engine.syncNow())
        #expect(h.remote.requests.isEmpty)
        #expect(SyncQueue(context: h.context).pendingCount(ownerId: nil) == 3)
    }

    /// NFR-09: reconnecting triggers a sync without any user action.
    @Test func reconnectTriggersASync() async throws {
        let h = try SyncHarness(reachable: false)
        let deck = try h.saveNewDeck()
        h.engine.start()

        h.reachability.set(true)
        for _ in 0..<100 where deck.syncState != .synced {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(deck.syncState == .synced)
        h.engine.stop()
    }

    /// NFR-02: a 100-card deck is one deck request and one card request.
    @Test func hundredCardDeckIsOneBatchedRequestPerTable() async throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck(prompts: (1...100).map { "Q\($0)" })
        #expect(await h.engine.syncNow())
        #expect(h.remote.requests.filter { $0 == "upsertDecks" }.count == 1)
        #expect(h.remote.requests.filter { $0 == "upsertCards" }.count == 1)
        #expect(h.remote.liveCards(deckId: deck.id).count == 100)
    }

    /// Activity 13.1 stress test: the connection drops halfway through
    /// pushing a 100-card deck (the deck row reached the server, its cards
    /// did not). Nothing is lost or duplicated: the deck falls back to
    /// LocallyPersisted and stays queued, and the retry after reconnecting
    /// sends all 100 cards once.
    @Test func connectionDropMidPushLosesAndDuplicatesNothing() async throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck(prompts: (1...100).map { "Q\($0)" })
        h.remote.goesOfflineAfter = "upsertDecks"

        #expect(await !h.engine.syncNow())
        #expect(h.remote.decks[deck.id] != nil)
        #expect(h.remote.liveCards(deckId: deck.id).isEmpty)
        #expect(deck.syncState == .locallyPersisted)
        #expect(h.queue.hasPending(.deck, id: deck.id))
        #expect(deck.activeCards.count == 100)

        h.remote.goesOfflineAfter = nil
        h.remote.isOffline = false
        #expect(await h.engine.syncNow())
        #expect(deck.syncState == .synced)
        #expect(!h.queue.hasPending(.deck, id: deck.id))
        let remoteCards = h.remote.liveCards(deckId: deck.id)
        #expect(remoteCards.count == 100)
        #expect(Set(remoteCards.map(\.card.prompt)).count == 100)
        #expect(h.remote.decks.count == 1)
        #expect(deck.activeCards.count == 100)
    }

    @Test func editsAfterSyncPushOnlyTheChangedCards() async throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck(prompts: ["Q1", "Q2", "Q3"])
        #expect(await h.engine.syncNow())

        var draft = DeckDraft(deck: deck)
        draft.cards[1].prompt = "Q2 edited"
        draft.cards.remove(at: 2)
        _ = try h.facade.saveDeck(draft)
        #expect(deck.syncState == .locallyPersisted)
        #expect(h.facade.pendingCount == 3)  // deck + edited card + tombstoned card

        #expect(await h.engine.syncNow())
        let remoteCards = h.remote.liveCards(deckId: deck.id)
        #expect(Set(remoteCards.map(\.card.prompt)) == ["Q1", "Q2 edited"])
        #expect(deck.syncState == .synced)
    }

    @Test func deletingASyncedDeckPushesATombstoneThenRemovesIt() async throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck()
        let id = deck.id
        #expect(await h.engine.syncNow())

        try h.facade.deleteDeck(deck)
        #expect(deck.deletedAt != nil)
        #expect(try h.queue.pendingOperation(.deck, id: id)?.op == .delete)

        #expect(await h.engine.syncNow())
        #expect(h.remote.decks[id]?.deletedAt != nil)
        #expect(try h.decks().isEmpty)
        #expect(h.remote.log.contains { $0.entityId == id && $0.op == .delete })
    }

    @Test func deletingANeverSyncedDeckIsLocalOnly() async throws {
        let h = try SyncHarness(reachable: false)
        let deck = try h.saveNewDeck()
        try h.facade.deleteDeck(deck)
        #expect(try h.decks().isEmpty)
        #expect(h.facade.pendingCount == 0)
    }

    @Test(arguments: [DeckSyncStateKind.syncing, .conflict, .drafting])
    func deleteIsRefusedWhileBusy(state: DeckSyncStateKind) throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck()
        deck.syncState = state
        #expect(throws: DeckBackendError.self) { try h.facade.deleteDeck(deck) }
        #expect(try h.decks().count == 1)
    }

    // MARK: Conflicts (Syncing → ConflictDetected → merge → re-push)

    @Test func concurrentEditsMergeAdditively() async throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck(prompts: ["Q1", "Q2"])
        #expect(await h.engine.syncNow())
        let q1 = try #require(deck.activeCards.first)

        // Another device renames the deck and adds a card.
        var remoteDeck = try #require(h.remote.decks[deck.id])
        remoteDeck.title = "Renamed elsewhere"
        remoteDeck.updatedAt = Date.now.addingTimeInterval(-60)
        h.remote.otherDeviceUpsert(deck: remoteDeck)
        let addedElsewhere = UUID()
        h.remote.otherDeviceUpsert(
            card: FlashcardPayload(id: addedElsewhere, prompt: "From phone B", answer: "A", sortIndex: 5,
                                   createdAt: .now, updatedAt: Date.now.addingTimeInterval(-60)),
            deckId: deck.id
        )

        // This device edits Q1 (later).
        var draft = DeckDraft(deck: deck)
        draft.cards[0].prompt = "Q1 edited here"
        _ = try h.facade.saveDeck(draft)

        #expect(await h.engine.syncNow())
        #expect(h.remote.requests.contains("fetchDeckSnapshot"))
        #expect(deck.syncState == .synced)
        // Local deck got the remote card; the title is local (the later write).
        #expect(Set(deck.activeCards.map(\.prompt)) == ["Q1 edited here", "Q2", "From phone B"])
        #expect(deck.title == "Swift")
        // Remote got the local edit.
        let remotePrompts = Set(h.remote.liveCards(deckId: deck.id).map(\.card.prompt))
        #expect(remotePrompts == ["Q1 edited here", "Q2", "From phone B"])
        #expect(h.remote.decks[deck.id]?.title == "Swift")
        #expect(q1.prompt == "Q1 edited here")
    }

    @Test func noConflictWhenOnlyThisDeviceWrote() async throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck()
        #expect(await h.engine.syncNow())
        var draft = DeckDraft(deck: deck)
        draft.title = "Second save"
        _ = try h.facade.saveDeck(draft)
        #expect(await h.engine.syncNow())
        #expect(!h.remote.requests.contains("fetchDeckSnapshot"))
        #expect(h.remote.decks[deck.id]?.title == "Second save")
    }

    // MARK: Pull

    @Test func pullCreatesRemoteDecksThroughTheFactory() async throws {
        let h = try SyncHarness()
        let deckID = UUID()
        h.remote.otherDeviceUpsert(deck: DeckPayload(id: deckID, title: "From the web", topicId: "topic-algorithms",
                                                     createdAt: .now, updatedAt: .now))
        h.remote.otherDeviceUpsert(
            card: FlashcardPayload(id: UUID(), prompt: "  Trimmed by the factory  ", answer: "A", createdAt: .now, updatedAt: .now),
            deckId: deckID
        )

        #expect(await h.engine.syncNow())
        let deck = try #require(try h.decks().first { $0.id == deckID })
        #expect(deck.syncState == .synced)
        #expect(deck.ownerId == SyncHarness.alice.id)
        #expect(deck.activeCards.map(\.prompt) == ["Trimmed by the factory"])
    }

    @Test func remoteTombstoneDeletesLocally() async throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck()
        let id = deck.id
        #expect(await h.engine.syncNow())

        var remoteDeck = try #require(h.remote.decks[id])
        remoteDeck.deletedAt = .now
        h.remote.otherDeviceUpsert(deck: remoteDeck)

        #expect(await h.engine.syncNow())
        #expect(try h.decks().isEmpty)
    }

    /// One pull with a deck's tombstone and an edit to one of its cards:
    /// the deck goes, and the card edit doesn't bring anything back.
    @Test func deckTombstoneAndCardEditInOnePull() async throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck()
        #expect(await h.engine.syncNow())
        let deckID = deck.id
        var deckPayload = deck.toPayload()
        deckPayload.deletedAt = .now
        deckPayload.serverUpdatedAt = .distantFuture
        var cardPayload = try #require(deck.activeCards.first).toPayload()
        cardPayload.prompt = "Edited remotely"
        cardPayload.updatedAt = .now.addingTimeInterval(60)

        let changes = RemoteChanges(decks: [deckPayload], cards: [RemoteCard(deckId: deckID, card: cardPayload)], cursor: nil)
        try RemoteChangeApplier(context: h.context).apply(changes, ownerId: SyncHarness.alice.id) { _ in true }
        try h.context.save()

        #expect(try h.decks().isEmpty)
        #expect(try h.context.fetchCount(FetchDescriptor<Flashcard>()) == 0)
    }

    @Test func pullSkipsDecksWithUnpushedChanges() async throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck()
        #expect(await h.engine.syncNow())
        h.reachability.isReachable = false
        var draft = DeckDraft(deck: deck)
        draft.title = "Local pending"
        _ = try h.facade.saveDeck(draft)

        let changes = RemoteChanges(
            decks: [DeckPayload(id: deck.id, title: "Remote", topicId: deck.topicId, createdAt: .now,
                                updatedAt: .now, serverUpdatedAt: .distantFuture)],
            cards: [], cursor: nil
        )
        let queue = h.queue
        try RemoteChangeApplier(context: h.context).apply(changes, ownerId: SyncHarness.alice.id) {
            $0.syncState == .synced && !queue.hasPending(.deck, id: $0.id)
        }
        #expect(deck.title == "Local pending")
    }

    // MARK: Two devices

    /// "Two simulators signed into the same account converge after
    /// concurrent edits."
    @Test func twoDevicesConverge() async throws {
        let server = MockRemoteStore()
        let phone = try SyncHarness(remote: server)
        let tablet = try SyncHarness(remote: server)

        let deck = try phone.saveNewDeck(prompts: ["Q1"])
        #expect(await phone.engine.syncNow())
        #expect(await tablet.engine.syncNow())
        let tabletDeck = try #require(try tablet.decks().first)
        #expect(tabletDeck.id == deck.id)

        // Offline on both, each adds a card.
        var phoneDraft = DeckDraft(deck: deck)
        phoneDraft.cards.append(CardDraft(prompt: "Phone card", answer: "A"))
        _ = try phone.facade.saveDeck(phoneDraft)
        var tabletDraft = DeckDraft(deck: tabletDeck)
        tabletDraft.cards.append(CardDraft(prompt: "Tablet card", answer: "A"))
        _ = try tablet.facade.saveDeck(tabletDraft)

        #expect(await phone.engine.syncNow())
        #expect(await tablet.engine.syncNow())
        #expect(await phone.engine.syncNow())

        let expected: Set = ["Q1", "Phone card", "Tablet card"]
        #expect(Set(deck.activeCards.map(\.prompt)) == expected)
        #expect(Set(tabletDeck.activeCards.map(\.prompt)) == expected)
        #expect(Set(server.liveCards(deckId: deck.id).map(\.card.prompt)) == expected)
        // No duplicates anywhere.
        #expect(deck.activeCards.count == 3 && tabletDeck.activeCards.count == 3)
        #expect(deck.syncState == .synced && tabletDeck.syncState == .synced)
    }

    // MARK: Profile (D10)

    @Test func profileXPMergesByMaxAndTakesTheRemoteName() async throws {
        let h = try SyncHarness()
        let profile = DataSeeder.ensureProfile(context: h.context)
        profile.totalXP = 300
        h.remote.profile = ProfilePayload(displayName: "Alice G.", avatarId: nil, totalXP: 900)

        #expect(await h.engine.syncNow())
        #expect(profile.totalXP == 900)
        #expect(profile.username == "Alice G.")

        profile.totalXP = 1_200
        #expect(await h.engine.syncNow())
        #expect(h.remote.profile?.totalXP == 1_200)
    }

    @Test func resetProgressWritesZeroExplicitly() async throws {
        let h = try SyncHarness()
        h.remote.profile = ProfilePayload(displayName: "Alice", avatarId: nil, totalXP: 900)
        let profile = DataSeeder.ensureProfile(context: h.context)
        try h.context.save()

        try LocalDataReset.resetProgress(context: h.context)
        h.facade.didResetProgress()
        #expect(await h.engine.syncNow())
        #expect(h.remote.profile?.totalXP == 0)
        #expect(profile.totalXP == 0)
        // After the explicit write, merging by max resumes.
        h.remote.profile?.totalXP = 50
        #expect(await h.engine.syncNow())
        #expect(profile.totalXP == 50)
    }

    // MARK: Sign-in / sign-out

    @Test func firstSignInClaimsGuestDecksAndPushesThem() async throws {
        let h = try SyncHarness(user: nil)
        let queued = try h.saveNewDeck(title: "Guest deck")
        // A deck from before sync existed has no queued operations.
        let legacy = try TestSupport.insertDeck(h.context, title: "Old deck")
        legacy.syncState = .locallyPersisted
        try h.context.save()

        h.auth.nextSignIn = SyncHarness.alice
        await h.facade.signInWithGoogle(presenting: UIViewController())

        #expect(h.facade.authState == .signedIn(SyncHarness.alice))
        for deck in [queued, legacy] {
            #expect(deck.ownerId == SyncHarness.alice.id)
            #expect(deck.syncState == .synced)
            #expect(h.remote.decks[deck.id] != nil)
        }
    }

    @Test func cancelledSignInStaysSignedOut() async throws {
        let h = try SyncHarness(user: nil)
        h.auth.nextSignIn = nil
        await h.facade.signInWithGoogle(presenting: UIViewController())
        #expect(h.facade.authState == .signedOut)
    }

    @Test func signOutRemovingDecksDeletesThisAccountsDecks() async throws {
        let h = try SyncHarness()
        let mine = try h.saveNewDeck(title: "Mine")
        let mineID = mine.id
        #expect(await h.engine.syncNow())
        let unsynced = try h.saveNewDeck(title: "Unsynced")
        #expect(h.facade.unsyncedChangeCount == 3)
        _ = unsynced

        await h.facade.signOut(removingLocalDecks: true)
        #expect(h.auth.signOutCount == 1)
        #expect(h.facade.authState == .signedOut)
        #expect(try h.decks().filter { $0.origin == .user }.isEmpty)
        #expect(SyncQueue(context: h.context).pendingCount(ownerId: SyncHarness.alice.id) == 0)
        #expect(h.remote.decks[mineID] != nil)
    }

    @Test func signOutKeepingDecksLeavesThemWithTheirOwner() async throws {
        let h = try SyncHarness()
        let deck = try h.saveNewDeck()
        await h.facade.signOut(removingLocalDecks: false)
        #expect(try h.decks().count == 1)
        #expect(deck.ownerId == SyncHarness.alice.id)
        // Another account's sign-in doesn't claim (or upload) them.
        let bob = AppUser(id: UUID(), email: "b@example.com", displayName: "Bob")
        h.auth.nextSignIn = bob
        await h.facade.signInWithGoogle(presenting: UIViewController())
        #expect(deck.ownerId == SyncHarness.alice.id)
        #expect(h.remote.decks[deck.id] == nil)
    }
}
