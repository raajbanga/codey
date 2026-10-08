import Foundation
import SwiftData
import os

enum ModelContainerFactory {
    /// Frozen store name. Schema changes go through CodeyMigrationPlan; never
    /// rename the store to "start fresh" (that silently drops user data).
    static let storeName = "CodeyStore_v1"

    static var schema: Schema { Schema(versionedSchema: CodeySchemaCurrent.self) }

    /// Opens (and migrates) the on-disk store. Failures are thrown, never
    /// "fixed" by deleting the store; LoadingView offers an explicit reset.
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, migrationPlan: CodeyMigrationPlan.self, configurations: config)
        }
        return try make(url: defaultStoreURL)
    }

    static func make(url: URL) throws -> ModelContainer {
        let config = ModelConfiguration(storeName, schema: schema, url: url)
        do {
            // With an explicit URL, SwiftData won't create Application Support
            // on a fresh install.
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            return try ModelContainer(for: schema, migrationPlan: CodeyMigrationPlan.self, configurations: config)
        } catch {
            Logger.persistence.error("Opening the store failed: \(String(describing: error))")
            throw error
        }
    }

    @MainActor
    static func makePreview() -> ModelContainer {
        let container = try! make(inMemory: true)
        DataSeeder.seedIfNeeded(context: container.mainContext)
        return container
    }

    /// Where SwiftData keeps a named store by default.
    static var defaultStoreURL: URL {
        ModelConfiguration(storeName).url
    }

    /// Deletes the store files. Only for the user-confirmed "Reset local data"
    /// escape hatch when the store can't be opened.
    static func destroyStore(at url: URL = defaultStoreURL) throws {
        let manager = FileManager.default
        for path in [url.path, url.path + "-shm", url.path + "-wal"] where manager.fileExists(atPath: path) {
            try manager.removeItem(atPath: path)
        }
        Logger.persistence.notice("Local store deleted by user request")
    }
}
