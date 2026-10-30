import Foundation
import SwiftData
import os

/// Additive merge for a deck in ConflictDetected (FR-47):
///   - cards = union by id;
///   - a card in both → the later change wins (updatedAt, or deletedAt for a
///     tombstone, so delete vs edit is also "later wins");
///   - deck title/topic (and a deck tombstone) → the later change wins.
/// Afterwards the caller resolves the deck (ConflictState.onResolve: markDirty
/// → LocallyPersisted) and re-pushes. Known limit: "later" uses device clocks.
@MainActor
struct ConflictResolver {
    let context: ModelContext
    var factory = FlashcardFactory()

    struct Outcome: Equatable {
        /// Local cards that won or exist only locally: push these.
        var cardsToPush: [UUID]
        /// Remote cards that won or were added locally.
        var cardsTakenFromRemote: [UUID]
    }

    func merge(_ deck: FlashcardDeck, with remote: RemoteDeckSnapshot) throws -> Outcome {
        if Self.isLater(Self.changeTime(remote.deck.updatedAt, remote.deck.deletedAt), than: Self.changeTime(deck.updatedAt, deck.deletedAt)) {
            deck.title = remote.deck.title
            deck.topicId = remote.deck.topicId
            deck.deletedAt = remote.deck.deletedAt
        }
        deck.serverUpdatedAt = remote.deck.serverUpdatedAt ?? deck.serverUpdatedAt

        var outcome = Outcome(cardsToPush: [], cardsTakenFromRemote: [])
        var local = deck.cards.keyed(by: \.id)
        for remoteCard in remote.cards {
            guard let id = remoteCard.card.id else { continue }
            if let card = local.removeValue(forKey: id) {
                let remoteTime = Self.changeTime(remoteCard.card.updatedAt, remoteCard.card.deletedAt)
                let localTime = Self.changeTime(card.updatedAt, card.deletedAt)
                if Self.isLater(remoteTime, than: localTime) {
                    try factory.applyRemote(remoteCard.card, to: card)
                    outcome.cardsTakenFromRemote.append(id)
                } else if Self.isLater(localTime, than: remoteTime) {
                    outcome.cardsToPush.append(id)
                }
            } else if remoteCard.card.deletedAt == nil {
                let card = try factory.createCard(from: remoteCard.card)
                context.insert(card)
                card.deck = deck
                outcome.cardsTakenFromRemote.append(id)
            }
        }
        // Cards only this device has.
        outcome.cardsToPush += local.keys

        // A deleted deck takes its cards with it.
        if let deletedAt = deck.deletedAt {
            for card in deck.cards where card.deletedAt == nil {
                card.deletedAt = deletedAt
            }
        }
        return outcome
    }

    /// Postgres keeps microseconds and Date keeps more, so a round trip can
    /// shift a timestamp slightly. Differences under 1 ms count as equal.
    static func isLater(_ a: Date, than b: Date) -> Bool {
        a.timeIntervalSince(b) > 0.001
    }

    /// When a row last changed: its edit time, or its delete time if later.
    static func changeTime(_ updatedAt: Date?, _ deletedAt: Date?) -> Date {
        max(updatedAt ?? .distantPast, deletedAt ?? .distantPast)
    }
}

// MARK: - [Pattern: Factory] Client (remote cards)
/// Applies a pull (fetchChanges) to decks that have no local changes. Dirty
/// decks are skipped: the push-time conflict check fetches and merges them.
/// New remote cards go through FlashcardFactory (factory rule for sync);
/// remote tombstones delete locally.
@MainActor
struct RemoteChangeApplier {
    let context: ModelContext
    var factory = FlashcardFactory()
    var now: () -> Date = Date.init

    /// Returns how many decks were created, updated, or deleted.
    @discardableResult
    func apply(_ changes: RemoteChanges, ownerId: UUID, isClean: (FlashcardDeck) -> Bool) throws -> Int {
        let store = SwiftDataService(context: context, factory: factory, now: now)
        var touched = 0

        for remote in changes.decks {
            if let deck = try store.fetch(id: remote.id) {
                guard deck.origin == .user, isClean(deck) else { continue }
                if let local = deck.serverUpdatedAt, let incoming = remote.serverUpdatedAt,
                   !ConflictResolver.isLater(incoming, than: local) { continue }
                if remote.deletedAt != nil {
                    context.delete(deck)
                } else {
                    deck.title = remote.title
                    deck.topicId = remote.topicId
                    deck.updatedAt = remote.updatedAt
                    deck.ownerId = ownerId
                    deck.serverUpdatedAt = remote.serverUpdatedAt
                    deck.lastSyncedAt = now()
                }
                touched += 1
            } else if remote.deletedAt == nil {
                let deck = FlashcardDeck(
                    id: remote.id,
                    title: remote.title,
                    topicId: remote.topicId,
                    origin: .user,
                    syncState: .synced,
                    ownerId: ownerId,
                    now: remote.createdAt
                )
                deck.updatedAt = remote.updatedAt
                deck.serverUpdatedAt = remote.serverUpdatedAt
                deck.lastSyncedAt = now()
                context.insert(deck)
                touched += 1
            }
        }

        for remote in changes.cards {
            guard let id = remote.card.id else { continue }
            guard let deck = try store.fetch(id: remote.deckId), deck.deletedAt == nil else {
                if (try? store.fetchCard(id: id)) == nil {
                    Logger.sync.debug("Pulled card skipped: its deck isn't on this device")
                }
                continue
            }
            guard deck.origin == .user, isClean(deck) else { continue }
            if let card = try store.fetchCard(id: id) {
                if remote.card.deletedAt != nil {
                    context.delete(card)
                } else if abs(ConflictResolver.changeTime(remote.card.updatedAt, remote.card.deletedAt)
                    .timeIntervalSince(ConflictResolver.changeTime(card.updatedAt, card.deletedAt))) > 0.001 {
                    try factory.applyRemote(remote.card, to: card)
                }
            } else if remote.card.deletedAt == nil {
                let card = try factory.createCard(from: remote.card)
                context.insert(card)
                card.deck = deck
            }
        }
        return touched
    }
}
