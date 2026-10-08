import SwiftData

/// Sprint 1/2 store: quiz bank + profile. FROZEN — this is what shipped in
/// CodeyStore_v1. The models live in Models/Question.swift, Topic.swift and
/// UserProfile.swift as extensions of this enum.
enum CodeySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [UserProfile.self, Topic.self, Question.self]
    }
}
