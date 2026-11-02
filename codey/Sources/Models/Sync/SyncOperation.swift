import Foundation
import SwiftData

/// What a queued operation points at (matches sync_log.entity).
enum SyncEntity: String, Codable, CaseIterable, Sendable {
    case deck
    case card
    case profile
}

/// Matches sync_log.op. A "delete" reaches the server as a tombstone
/// (deleted_at set), so other devices can pull it.
enum SyncOperationKind: String, Codable, CaseIterable, Sendable {
    case upsert
    case delete

    /// The operation that pushes a row's current state: a tombstone is a delete.
    init(deletedAt: Date?) {
        self = deletedAt == nil ? .upsert : .delete
    }
}

extension CodeySchemaV6 {
    /// One pending change for the server (FR-45). Queued even for guests;
    /// the queue drains after sign-in. Coalesced per entity by SyncQueue.
    @Model
    final class SyncOperation {
        @Attribute(.unique) var id: UUID
        var entityRaw: String
        var entityId: UUID
        var opRaw: String
        var enqueuedAt: Date
        var attempts: Int = 0
        var lastError: String?
        /// nil = guest; claimed by the account on first sign-in.
        var ownerId: UUID?

        init(
            id: UUID = UUID(),
            entity: SyncEntity,
            entityId: UUID,
            op: SyncOperationKind,
            ownerId: UUID?,
            enqueuedAt: Date
        ) {
            self.id = id
            self.entityRaw = entity.rawValue
            self.entityId = entityId
            self.opRaw = op.rawValue
            self.ownerId = ownerId
            self.enqueuedAt = enqueuedAt
        }
    }
}

extension SyncOperation {
    /// nil for a raw value this build doesn't know (written by a newer
    /// one). Such operations match no push filter and are never sent.
    var entity: SyncEntity? {
        SyncEntity(rawValue: entityRaw)
    }

    var op: SyncOperationKind {
        get { SyncOperationKind(rawValue: opRaw) ?? .upsert }
        set { opRaw = newValue.rawValue }
    }
}
