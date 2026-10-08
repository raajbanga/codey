import Foundation
import os

/// What the server said about a push (Fig. 7 arrows out of Syncing).
enum RemoteResult: Equatable, Sendable {
    /// 200 ACK. Carries the row's new server_updated_at (the next conflict cursor).
    case ack(serverUpdatedAt: Date)
    /// Network drop or timeout: retry later.
    case networkFailure
    /// The remote deck changed since our last sync (timestamp mismatch).
    case timestampMismatch
}

/// State pattern (§9.3). ALL five states live in this file (R9). SwiftData
/// can't store a protocol existential, so a deck persists only its
/// DeckSyncStateKind and rebuilds the state object on demand
/// (FlashcardDeck.currentState).
///
/// Each event returns the next state. States change only the deck fields their
/// arrow names (markDirty, lastSyncedAt, the tombstone). Queueing is done by
/// the caller (BackendFacade / SyncEngine). A call with no arrow returns self.
protocol DeckSyncState {
    var kind: DeckSyncStateKind { get }
    var name: String { get }
    func onSave(_ deck: FlashcardDeck) -> any DeckSyncState
    func onEdit(_ deck: FlashcardDeck) -> any DeckSyncState
    func onPush(_ deck: FlashcardDeck) -> any DeckSyncState
    func onRemoteResponse(_ deck: FlashcardDeck, _ result: RemoteResult) -> any DeckSyncState
    func onResolve(_ deck: FlashcardDeck) -> any DeckSyncState
    /// nil = deleting isn't allowed in this state.
    func onDelete(_ deck: FlashcardDeck) -> (any DeckSyncState)?
}

extension DeckSyncState {
    var name: String { kind.displayName }

    // Default: no arrow for this event, so stay put.
    func onSave(_ deck: FlashcardDeck) -> any DeckSyncState { ignored("save") }
    func onEdit(_ deck: FlashcardDeck) -> any DeckSyncState { ignored("edit") }
    func onPush(_ deck: FlashcardDeck) -> any DeckSyncState { ignored("push") }
    func onRemoteResponse(_ deck: FlashcardDeck, _ result: RemoteResult) -> any DeckSyncState { ignored("remote response") }
    func onResolve(_ deck: FlashcardDeck) -> any DeckSyncState { ignored("resolve") }
    func onDelete(_ deck: FlashcardDeck) -> (any DeckSyncState)? { nil }

    fileprivate func ignored(_ event: String) -> any DeckSyncState {
        Logger.sync.debug("\(event, privacy: .public) ignored in state \(kind.rawValue, privacy: .public)")
        return self
    }

    /// LocallyPersisted | Synced ──delete──▶ tombstone. The tombstoned deck
    /// waits in LocallyPersisted until the delete syncs.
    fileprivate func tombstone(_ deck: FlashcardDeck) -> any DeckSyncState {
        let now = Date.now
        deck.deletedAt = now
        deck.markDirty(at: now)
        for card in deck.cards where card.deletedAt == nil {
            card.deletedAt = now
        }
        return LocallyPersistedState()
    }
}

/// In the editor. Only a valid save leaves it (invalid saves never reach the
/// state: the validator throws first, so the deck stays Drafting).
struct DraftingState: DeckSyncState {
    let kind = DeckSyncStateKind.drafting

    func onSave(_ deck: FlashcardDeck) -> any DeckSyncState {
        deck.markDirty()
        return LocallyPersistedState()
    }

    func onEdit(_ deck: FlashcardDeck) -> any DeckSyncState { self }
}

/// Saved on the device with changes the server hasn't seen.
struct LocallyPersistedState: DeckSyncState {
    let kind = DeckSyncStateKind.locallyPersisted

    func onEdit(_ deck: FlashcardDeck) -> any DeckSyncState { DraftingState() }

    func onPush(_ deck: FlashcardDeck) -> any DeckSyncState { SyncingState() }

    func onDelete(_ deck: FlashcardDeck) -> (any DeckSyncState)? { tombstone(deck) }
}

/// A push is in flight.
struct SyncingState: DeckSyncState {
    let kind = DeckSyncStateKind.syncing

    /// Already pushing.
    func onPush(_ deck: FlashcardDeck) -> any DeckSyncState { self }

    func onRemoteResponse(_ deck: FlashcardDeck, _ result: RemoteResult) -> any DeckSyncState {
        switch result {
        case .ack(let serverUpdatedAt):
            deck.lastSyncedAt = .now
            deck.serverUpdatedAt = serverUpdatedAt
            return SyncedState()
        case .networkFailure:
            return LocallyPersistedState()
        case .timestampMismatch:
            return ConflictState()
        }
    }
}

/// Local and remote agree.
struct SyncedState: DeckSyncState {
    let kind = DeckSyncStateKind.synced

    func onEdit(_ deck: FlashcardDeck) -> any DeckSyncState { DraftingState() }

    func onDelete(_ deck: FlashcardDeck) -> (any DeckSyncState)? { tombstone(deck) }
}

/// Someone else changed the deck since our last sync. The additive merge
/// (ConflictResolver) runs first; resolving marks the result dirty for re-push.
struct ConflictState: DeckSyncState {
    let kind = DeckSyncStateKind.conflict

    func onResolve(_ deck: FlashcardDeck) -> any DeckSyncState {
        deck.markDirty()
        return LocallyPersistedState()
    }
}

// MARK: - Context

/// FlashcardDeck is the State pattern's context: it persists the kind and
/// forwards each event to the current state. Starter decks never edit,
/// delete, or push.
extension FlashcardDeck {
    var currentState: any DeckSyncState {
        switch syncState {
        case .drafting: DraftingState()
        case .locallyPersisted: LocallyPersistedState()
        case .syncing: SyncingState()
        case .synced: SyncedState()
        case .conflict: ConflictState()
        }
    }

    func setState(_ state: any DeckSyncState) {
        syncState = state.kind
    }

    func save() {
        guard origin == .user else { return }
        setState(currentState.onSave(self))
    }

    func edit() {
        guard origin == .user else { return }
        setState(currentState.onEdit(self))
    }

    func push() {
        guard origin == .user else { return }
        setState(currentState.onPush(self))
    }

    func receive(_ result: RemoteResult) {
        guard origin == .user else { return }
        setState(currentState.onRemoteResponse(self, result))
    }

    func resolve() {
        guard origin == .user else { return }
        setState(currentState.onResolve(self))
    }

    /// Tombstones the deck if its state allows it. Returns false if not.
    /// (Never-synced decks are hard-deleted by the caller instead.)
    @discardableResult
    func delete() -> Bool {
        guard origin == .user, let next = currentState.onDelete(self) else { return false }
        setState(next)
        return true
    }

    /// Fig. 7: only user decks that are LocallyPersisted or Synced can be
    /// deleted (not while drafting, syncing, or in conflict).
    var canDelete: Bool { deleteBlockedReason == nil }

    var deleteBlockedReason: String? {
        guard origin == .user else { return "Starter decks can be hidden, not deleted." }
        switch syncState {
        case .locallyPersisted, .synced: return nil
        case .drafting: return "Finish editing this deck first."
        case .syncing: return "Wait for this deck to finish syncing."
        case .conflict: return "Resolve this deck's sync conflict first."
        }
    }

    /// Opening the builder is the edit arrow, which Syncing/Conflict don't have.
    var canEdit: Bool {
        origin == .user && syncState != .syncing && syncState != .conflict
    }

    /// Launch-time crash recovery: a killed app must not strand a deck.
    /// Syncing → LocallyPersisted (retry); a persisted Drafting deck →
    /// LocallyPersisted (Drafting is otherwise an in-editor state only).
    /// Returns whether anything changed.
    @discardableResult
    func recoverAfterLaunch() -> Bool {
        guard origin == .user else { return false }
        switch syncState {
        case .syncing:
            setState(currentState.onRemoteResponse(self, .networkFailure))
            return true
        case .drafting:
            setState(currentState.onSave(self))
            return true
        case .locallyPersisted, .synced, .conflict:
            return false
        }
    }
}
