import Foundation
import SwiftData

enum ModelContainerFactory {
    /// Bump when @Model definitions change incompatibly (e.g. UUID → String ids).
    static let storeSchemaVersion = 1

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([UserProfile.self, Topic.self, Question.self])

        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: config)
        }

        let config = ModelConfiguration(
            "CodeyStore_v\(storeSchemaVersion)",
            schema: schema
        )

        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            try wipeStore(at: config.url)
            return try ModelContainer(for: schema, configurations: config)
        }
    }

    @MainActor
    static func makePreview() -> ModelContainer {
        let container = try! make(inMemory: true)
        DataSeeder.seedIfNeeded(context: container.mainContext)
        return container
    }

    private static func wipeStore(at url: URL) throws {
        let manager = FileManager.default
        for path in [url.path, url.path + "-shm", url.path + "-wal"] {
            if manager.fileExists(atPath: path) {
                try manager.removeItem(atPath: path)
            }
        }
    }
}
