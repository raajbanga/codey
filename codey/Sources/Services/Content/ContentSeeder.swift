import Foundation
import SwiftData
import os

/// Puts content into the store: at boot from the last download (else the
/// bundle), and again whenever a download differs from the last one. The
/// seeders upsert by id, so progress, mastery and hidden decks survive.
@MainActor
enum ContentSeeder {
    /// The content boot seeds from. A download the loaders now reject (an
    /// older build's cache, a bad write) is dropped for the bundle.
    static func load() throws -> (files: ContentFiles, content: ContentFiles.Content) {
        let useCache = !AppLaunchOptions.usesInMemoryStore
        if useCache, let cached = ContentFiles.cached() {
            do {
                return (cached, try cached.validated())
            } catch {
                Logger.seeding.error("Downloaded content rejected, using the bundle: \(String(describing: error))")
                try? FileManager.default.removeItem(at: ContentFiles.cacheDirectory)
            }
        }
        guard let bundled = ContentFiles.bundled() else { throw QuestionBankLoaderError.fileNotFound }
        return (bundled, try bundled.validated())
    }

    /// Seeds topics, questions and starter decks, records the stamp, and
    /// shows the exercises.
    static func seed(_ content: ContentFiles.Content, stamp: String, context: ModelContext) throws {
        try DataSeeder.seed(context: context, bank: content.bank)
        try StarterDeckLoader.seed(context: context, file: content.decks)
        BundledContentStamp.record(stamp)
        ExerciseCatalog.shared.replace(with: content.exercises)
    }

    /// A fresh download: when it differs from the last one and passes the
    /// loaders, it's cached and seeded. Returns whether anything changed.
    @discardableResult
    static func apply(_ downloaded: ContentFiles, context: ModelContext) throws -> Bool {
        guard downloaded != ContentFiles.cached() else { return false }
        let content = try downloaded.validated()
        try downloaded.write()
        try seed(content, stamp: downloaded.stamp, context: context)
        Logger.seeding.info("Content updated from Supabase: \(content.bank.questions.count) questions, \(content.decks.decks.count) decks, \(content.exercises.count) exercises")
        return true
    }
}
