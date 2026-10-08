import Foundation
import SwiftData
import os

/// The pending-changes queue (FR-45). Doc name: ISyncQueue.
@MainActor
protocol ISyncQueue {
    /// Adds an operation, coalescing with any pending one for the same entity.
    func enqueue(_ entity: SyncEntity, id: UUID, op: SyncOperationKind, ownerId: UUID?) throws
    /// Oldest first, only operations owned by `ownerId`.
    func peekBatch(limit: Int, ownerId: UUID) throws -> [SyncOperation]
    func markDone(_ operations: [SyncOperation]) throws
    func markFailed(_ operations: [SyncOperation], error: String) throws
}

/// SwiftData-backed queue. Coalescing keeps at most one operation per entity:
///   - an upsert replaces a pending upsert (only the latest state matters);
///   - a delete replaces any pending upsert;
///   - an upsert after a delete can't happen (the tombstone blocks edits), so
///     it's ignored and logged.
@MainActor
struct SyncQueue: ISyncQueue {
    let context: ModelContext
    var now: () -> Date = Date.init

    func enqueue(_ entity: SyncEntity, id: UUID, op: SyncOperationKind, ownerId: UUID?) throws {
        if let pending = try pendingOperation(entity, id: id) {
            switch (pending.op, op) {
            case (.delete, .upsert):
                Logger.sync.error("Upsert after delete ignored for a \(entity.rawValue, privacy: .public)")
                return
            case (_, .delete), (.upsert, .upsert):
                context.delete(pending)
            }
        }
        context.insert(SyncOperation(entity: entity, entityId: id, op: op, ownerId: ownerId, enqueuedAt: now()))
    }

    func peekBatch(limit: Int, ownerId: UUID) throws -> [SyncOperation] {
        let owner: UUID? = ownerId
        var descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.ownerId == owner },
            sortBy: [SortDescriptor(\.enqueuedAt)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func markDone(_ operations: [SyncOperation]) throws {
        for operation in operations {
            context.delete(operation)
        }
        try context.save()
    }

    func markFailed(_ operations: [SyncOperation], error: String) throws {
        for operation in operations {
            operation.attempts += 1
            operation.lastError = error
        }
        try context.save()
    }

    // MARK: Queries used by the facade/engine

    func pendingOperation(_ entity: SyncEntity, id: UUID) throws -> SyncOperation? {
        let raw = entity.rawValue
        var descriptor = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.entityRaw == raw && $0.entityId == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func hasPending(_ entity: SyncEntity, id: UUID) -> Bool {
        ((try? pendingOperation(entity, id: id)) ?? nil) != nil
    }

    func pendingCount(ownerId: UUID?) -> Int {
        let owner = ownerId
        return (try? context.fetchCount(FetchDescriptor<SyncOperation>(predicate: #Predicate { $0.ownerId == owner }))) ?? 0
    }

    /// Drops every pending operation for these entities (hard-deleted rows
    /// the server never saw).
    func remove(_ entity: SyncEntity, ids: [UUID]) throws {
        for id in ids {
            if let pending = try pendingOperation(entity, id: id) {
                context.delete(pending)
            }
        }
    }

    /// First sign-in: guest deck/card operations now belong to the account.
    /// Guest profile operations are dropped: the account's XP merges by max.
    func claimGuestOperations(for ownerId: UUID) throws {
        let guest: UUID? = nil
        for operation in try context.fetch(FetchDescriptor<SyncOperation>(predicate: #Predicate { $0.ownerId == guest })) {
            if operation.entity == .profile {
                context.delete(operation)
            } else {
                operation.ownerId = ownerId
            }
        }
    }

    func removeAll(ownerId: UUID) throws {
        let owner: UUID? = ownerId
        for operation in try context.fetch(FetchDescriptor<SyncOperation>(predicate: #Predicate { $0.ownerId == owner })) {
            context.delete(operation)
        }
    }
}
