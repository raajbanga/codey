import Foundation
import SwiftData
import os

/// Builds the app's single ModelContainer (on disk, or in memory for tests
/// and UI tests) with the current schema and CodeyMigrationPlan.
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
            applyFileProtection(storeURL: url)
            let container = try ModelContainer(for: schema, migrationPlan: CodeyMigrationPlan.self, configurations: config)
            // SQLite creates the -wal/-shm files on open; protect those too.
            applyFileProtection(storeURL: url)
            return container
        } catch {
            Logger.persistence.error("Opening the store failed: \(String(describing: error))")
            throw error
        }
    }

    /// A seeded in-memory store for SwiftUI previews.
    @MainActor
    static func makePreview() -> ModelContainer {
        let container = try! make(inMemory: true)
        try! DataSeeder.seed(context: container.mainContext, bank: QuestionBankLoader.loadBank())
        try! StarterDeckLoader.seed(context: container.mainContext)
        return container
    }

    /// NFR-04 (O6): encrypted while the device is locked. .completeUnlessOpen
    /// rather than .complete, so a sync still writing just after the device
    /// locks keeps its open SQLite handles; new files can't be created until
    /// unlock.
    static let fileProtection = FileProtectionType.completeUnlessOpen

    /// Sets the protection class on the store's folder (new files inherit it)
    /// and on the store, -wal, and -shm files that already exist. Returns the
    /// paths it protected. (The Simulator accepts the attribute but doesn't
    /// store it; only a device reports it back.)
    @discardableResult
    static func applyFileProtection(storeURL url: URL) -> [String] {
        let manager = FileManager.default
        let paths = [url.deletingLastPathComponent().path, url.path, url.path + "-wal", url.path + "-shm"]
        var protected: [String] = []
        for path in paths where manager.fileExists(atPath: path) {
            do {
                try manager.setAttributes([.protectionKey: fileProtection], ofItemAtPath: path)
                protected.append(path)
            } catch {
                Logger.persistence.error("Setting file protection failed: \(String(describing: error))")
            }
        }
        return protected
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
