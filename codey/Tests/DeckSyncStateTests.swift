import Foundation
import SwiftData
import Testing
@testable import codey

/// R9: one test per Fig. 7 arrow, plus every disallowed operation.
@MainActor
struct DeckSyncStateTests {
    private func deck(_ state: DeckSyncStateKind, origin: DeckOrigin = .user) throws -> (FlashcardDeck, ModelContext) {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertDeck(context, origin: origin, prompts: ["Q1", "Q2"])
        deck.syncState = state
        deck.updatedAt = .distantPast
        try context.save()
        return (deck, context)
    }

    @Test func newDeckStartsInDrafting() {
        let deck = FlashcardDeck(title: "New", topicId: "t", origin: .user)
        #expect(deck.syncState == .drafting)
        #expect(deck.currentState is DraftingState)
    }

    @Test(arguments: DeckSyncStateKind.allCases)
    func currentStateRebuildsFromThePersistedKind(kind: DeckSyncStateKind) throws {
        let (deck, _) = try deck(kind)
        #expect(deck.currentState.kind == kind)
        #expect(deck.currentState.name == kind.displayName)
    }

    // MARK: Arrows

    @Test func draftingValidSaveGoesToLocallyPersistedAndMarksDirty() throws {
        let (deck, _) = try deck(.drafting)
        deck.save()
        #expect(deck.syncState == .locallyPersisted)
        #expect(deck.updatedAt > .distantPast)
    }

    @Test func draftingInvalidSaveStaysDrafting() throws {
        let harness = try SyncHarness(user: nil)
        let deck = try harness.saveNewDeck()
        deck.syncState = .drafting
        try harness.context.save()

        var draft = DeckDraft(deck: deck)
        draft.cards[0].prompt = "   "
        #expect(throws: DeckBackendError.self) { try harness.facade.saveDeck(draft) }
        #expect(deck.syncState == .drafting)
        #expect(deck.activeCards[0].prompt == "Q1")
    }

    @Test func locallyPersistedEditGoesToDrafting() throws {
        let (deck, _) = try deck(.locallyPersisted)
        deck.edit()
        #expect(deck.syncState == .drafting)
    }

    @Test func locallyPersistedPushGoesToSyncing() throws {
        let (deck, _) = try deck(.locallyPersisted)
        deck.push()
        #expect(deck.syncState == .syncing)
    }

    @Test func syncingPushIsANoOp() throws {
        let (deck, _) = try deck(.syncing)
        deck.push()
        #expect(deck.syncState == .syncing)
    }

    @Test func syncingNetworkDropGoesBackToLocallyPersisted() throws {
        let (deck, _) = try deck(.syncing)
        deck.receive(.networkFailure)
        #expect(deck.syncState == .locallyPersisted)
        #expect(deck.lastSyncedAt == nil)
    }

    @Test func syncingAckGoesToSyncedAndRecordsTheServerTime() throws {
        let (deck, _) = try deck(.syncing)
        let serverTime = Date(timeIntervalSince1970: 2_000_000_000)
        deck.receive(.ack(serverUpdatedAt: serverTime))
        #expect(deck.syncState == .synced)
        #expect(deck.lastSyncedAt != nil)
        #expect(deck.serverUpdatedAt == serverTime)
    }

    @Test func syncingTimestampMismatchGoesToConflict() throws {
        let (deck, _) = try deck(.syncing)
        deck.receive(.timestampMismatch)
        #expect(deck.syncState == .conflict)
    }

    @Test func conflictResolveGoesToLocallyPersistedAndMarksDirty() throws {
        let (deck, _) = try deck(.conflict)
        deck.resolve()
        #expect(deck.syncState == .locallyPersisted)
        #expect(deck.updatedAt > .distantPast)
    }

    @Test func syncedEditGoesToDrafting() throws {
        let (deck, _) = try deck(.synced)
        deck.edit()
        #expect(deck.syncState == .drafting)
    }

    @Test(arguments: [DeckSyncStateKind.locallyPersisted, .synced])
    func deleteTombstonesTheDeckAndItsCards(kind: DeckSyncStateKind) throws {
        let (deck, _) = try deck(kind)
        #expect(deck.canDelete)
        #expect(deck.delete())
        #expect(deck.deletedAt != nil)
        #expect(deck.cards.allSatisfy { $0.deletedAt != nil })
        #expect(deck.syncState == .locallyPersisted)
    }

    // MARK: Disallowed

    @Test(arguments: [DeckSyncStateKind.drafting, .syncing, .conflict])
    func deleteIsNotAllowed(kind: DeckSyncStateKind) throws {
        let (deck, _) = try deck(kind)
        #expect(!deck.canDelete)
        #expect(deck.deleteBlockedReason != nil)
        #expect(!deck.delete())
        #expect(deck.deletedAt == nil)
        #expect(deck.syncState == kind)
    }

    @Test(arguments: DeckSyncStateKind.allCases)
    func starterDecksNeverEditDeleteOrPush(kind: DeckSyncStateKind) throws {
        let (deck, _) = try deck(kind, origin: .starter)
        deck.edit()
        deck.push()
        deck.save()
        deck.receive(.ack(serverUpdatedAt: .now))
        deck.resolve()
        #expect(!deck.delete())
        #expect(deck.syncState == kind)
        #expect(!deck.canDelete)
        #expect(!deck.canEdit)
    }

    /// Events with no arrow return the same state ("any other call is a no-op").
    @Test func eventsWithoutAnArrowAreNoOps() throws {
        let cases: [(DeckSyncStateKind, (FlashcardDeck) -> Void)] = [
            (.drafting, { $0.push() }),
            (.drafting, { $0.receive(.ack(serverUpdatedAt: .now)) }),
            (.drafting, { $0.resolve() }),
            (.drafting, { $0.edit() }),
            (.locallyPersisted, { $0.save() }),
            (.locallyPersisted, { $0.receive(.networkFailure) }),
            (.locallyPersisted, { $0.resolve() }),
            (.syncing, { $0.edit() }),
            (.syncing, { $0.save() }),
            (.syncing, { $0.resolve() }),
            (.synced, { $0.push() }),
            (.synced, { $0.save() }),
            (.synced, { $0.receive(.timestampMismatch) }),
            (.synced, { $0.resolve() }),
            (.conflict, { $0.edit() }),
            (.conflict, { $0.push() }),
            (.conflict, { $0.save() }),
            (.conflict, { $0.receive(.ack(serverUpdatedAt: .now)) }),
        ]
        for (kind, event) in cases {
            let (deck, _) = try deck(kind)
            event(deck)
            #expect(deck.syncState == kind, "\(kind) changed")
        }
    }

    @Test(arguments: DeckSyncStateKind.allCases)
    func editIsBlockedOnlyWhileSyncingOrInConflict(kind: DeckSyncStateKind) throws {
        let (deck, _) = try deck(kind)
        #expect(deck.canEdit == (kind != .syncing && kind != .conflict))
    }

    // MARK: Crash recovery

    @Test func recoveryMovesSyncingAndDraftingToLocallyPersisted() throws {
        for kind in [DeckSyncStateKind.syncing, .drafting] {
            let (deck, _) = try deck(kind)
            #expect(deck.recoverAfterLaunch())
            #expect(deck.syncState == .locallyPersisted)
        }
        for kind in [DeckSyncStateKind.locallyPersisted, .synced, .conflict] {
            let (deck, _) = try deck(kind)
            #expect(!deck.recoverAfterLaunch())
            #expect(deck.syncState == kind)
        }
    }

    @Test func facadeRecoveryRequeuesStrandedDecks() throws {
        let harness = try SyncHarness(user: nil)
        let deck = try TestSupport.insertDeck(harness.context)
        deck.syncState = .syncing
        try harness.context.save()

        harness.facade.recoverDecks()
        #expect(deck.syncState == .locallyPersisted)
        #expect(harness.queue.hasPending(.deck, id: deck.id))
    }
}
