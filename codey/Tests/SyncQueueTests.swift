import Foundation
import SwiftData
import Testing
@testable import codey

/// FR-45 queue: coalescing, ownership, and batch bookkeeping.
@MainActor
struct SyncQueueTests {
    private let owner = UUID()

    private func makeQueue() throws -> (SyncQueue, ModelContext) {
        let context = try TestSupport.inMemoryContext()
        var tick = Date(timeIntervalSince1970: 1_000)
        let queue = SyncQueue(context: context) {
            tick = tick.addingTimeInterval(1)
            return tick
        }
        return (queue, context)
    }

    private func all(_ context: ModelContext) throws -> [SyncOperation] {
        try context.fetch(FetchDescriptor<SyncOperation>(sortBy: [SortDescriptor(\.enqueuedAt)]))
    }

    @Test func unknownEntityIsNotReadAsADeck() {
        let operation = SyncOperation(entity: .deck, entityId: UUID(), op: .upsert, ownerId: owner, enqueuedAt: .now)
        operation.entityRaw = "widget"  // written by a newer build
        #expect(operation.entity == nil)
    }

    @Test func upsertReplacesAPendingUpsert() throws {
        let (queue, context) = try makeQueue()
        let id = UUID()
        try queue.enqueue(.deck, id: id, op: .upsert, ownerId: owner)
        let first = try all(context)[0].enqueuedAt
        try queue.enqueue(.deck, id: id, op: .upsert, ownerId: owner)

        let operations = try all(context)
        #expect(operations.count == 1)
        #expect(operations[0].op == .upsert)
        #expect(operations[0].enqueuedAt > first)
    }

    @Test func deleteReplacesAPendingUpsert() throws {
        let (queue, context) = try makeQueue()
        let id = UUID()
        try queue.enqueue(.card, id: id, op: .upsert, ownerId: owner)
        try queue.enqueue(.card, id: id, op: .delete, ownerId: owner)

        let operations = try all(context)
        #expect(operations.count == 1)
        #expect(operations[0].op == .delete)
    }

    @Test func upsertAfterDeleteIsIgnored() throws {
        let (queue, context) = try makeQueue()
        let id = UUID()
        try queue.enqueue(.deck, id: id, op: .delete, ownerId: owner)
        try queue.enqueue(.deck, id: id, op: .upsert, ownerId: owner)

        let operations = try all(context)
        #expect(operations.count == 1)
        #expect(operations[0].op == .delete)
    }

    @Test func differentEntitiesDontCoalesce() throws {
        let (queue, context) = try makeQueue()
        let id = UUID()
        try queue.enqueue(.deck, id: id, op: .upsert, ownerId: owner)
        try queue.enqueue(.card, id: id, op: .upsert, ownerId: owner)
        try queue.enqueue(.deck, id: UUID(), op: .upsert, ownerId: owner)
        #expect(try all(context).count == 3)
    }

    @Test func peekBatchIsOldestFirstOwnedAndLimited() throws {
        let (queue, _) = try makeQueue()
        let ids = (0..<5).map { _ in UUID() }
        for id in ids {
            try queue.enqueue(.card, id: id, op: .upsert, ownerId: owner)
        }
        try queue.enqueue(.card, id: UUID(), op: .upsert, ownerId: UUID())
        try queue.enqueue(.card, id: UUID(), op: .upsert, ownerId: nil)

        let batch = try queue.peekBatch(limit: 3, ownerId: owner)
        #expect(batch.map(\.entityId) == Array(ids.prefix(3)))
        #expect(try queue.peekBatch(limit: 100, ownerId: owner).count == 5)
        #expect(queue.pendingCount(ownerId: owner) == 5)
        #expect(queue.pendingCount(ownerId: nil) == 1)
    }

    @Test func markDoneRemovesAndMarkFailedCounts() throws {
        let (queue, context) = try makeQueue()
        try queue.enqueue(.deck, id: UUID(), op: .upsert, ownerId: owner)
        try queue.enqueue(.deck, id: UUID(), op: .upsert, ownerId: owner)
        let batch = try queue.peekBatch(limit: 10, ownerId: owner)

        try queue.markFailed([batch[0]], error: "timeout")
        #expect(batch[0].attempts == 1)
        #expect(batch[0].lastError == "timeout")

        try queue.markDone([batch[1]])
        #expect(try all(context).map(\.id) == [batch[0].id])
    }

    /// Guests queue too; the first sign-in claims deck/card work and drops
    /// guest profile operations (the account's XP merges by max instead).
    @Test func guestOperationsAreClaimedOnSignIn() throws {
        let (queue, context) = try makeQueue()
        try queue.enqueue(.deck, id: UUID(), op: .upsert, ownerId: nil)
        try queue.enqueue(.card, id: UUID(), op: .upsert, ownerId: nil)
        try queue.enqueue(.profile, id: UUID(), op: .upsert, ownerId: nil)

        try queue.claimGuestOperations(for: owner)
        let operations = try all(context)
        #expect(operations.count == 2)
        #expect(operations.allSatisfy { $0.ownerId == owner && $0.entity != .profile })
    }

    @Test func removeAllOnlyTouchesThatOwner() throws {
        let (queue, _) = try makeQueue()
        try queue.enqueue(.deck, id: UUID(), op: .upsert, ownerId: owner)
        try queue.enqueue(.deck, id: UUID(), op: .upsert, ownerId: nil)
        try queue.removeAll(ownerId: owner)
        #expect(queue.pendingCount(ownerId: owner) == 0)
        #expect(queue.pendingCount(ownerId: nil) == 1)
    }
}
