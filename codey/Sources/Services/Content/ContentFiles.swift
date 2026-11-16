import CryptoKit
import Foundation

/// The app's teaching content as its three JSON files (questions-seed,
/// starter-decks, exercises), in the bundled format.
///
/// Supabase is the source (the content_* tables): the app downloads them,
/// checks them with the same loaders as the bundle, and keeps the last good
/// download in Application Support. The bundled copies are the fallback for
/// a first launch offline, demo mode, builds without backend keys, and tests.
struct ContentFiles: Equatable, Sendable {
    var questions: Data
    var decks: Data
    var exercises: Data

    private static let names = (questions: "questions-seed", decks: "starter-decks", exercises: "exercises")

    /// The copies shipped in the app.
    static func bundled(_ bundle: Bundle = .main) -> ContentFiles? {
        func read(_ name: String) -> Data? {
            bundle.url(forResource: name, withExtension: "json").flatMap { try? Data(contentsOf: $0) }
        }
        guard let questions = read(names.questions), let decks = read(names.decks), let exercises = read(names.exercises) else {
            return nil
        }
        return ContentFiles(questions: questions, decks: decks, exercises: exercises)
    }

    /// The last download, only when all three files are there.
    static func cached(in directory: URL = cacheDirectory) -> ContentFiles? {
        func read(_ name: String) -> Data? { try? Data(contentsOf: directory.appending(path: "\(name).json")) }
        guard let questions = read(names.questions), let decks = read(names.decks), let exercises = read(names.exercises) else {
            return nil
        }
        return ContentFiles(questions: questions, decks: decks, exercises: exercises)
    }

    /// What boot seeds from: the download, else the bundle. A store in
    /// memory (UI tests) always gets the bundle, so tests see known content.
    static func current(useCache: Bool = !AppLaunchOptions.usesInMemoryStore) -> ContentFiles? {
        (useCache ? cached() : nil) ?? bundled()
    }

    static var cacheDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "content", directoryHint: .isDirectory)
    }

    /// Writes all three, each atomically.
    func write(to directory: URL = Self.cacheDirectory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, data) in [(Self.names.questions, questions), (Self.names.decks, decks), (Self.names.exercises, exercises)] {
            try data.write(to: directory.appending(path: "\(name).json"), options: .atomic)
        }
    }

    /// SHA-256 of the three files: boot skips reseeding when it matches the
    /// stamp recorded after the last seed.
    var stamp: String {
        var hasher = SHA256()
        for data in [questions, decks, exercises] { hasher.update(data: data) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Decoded and checked with the loaders; throws on anything they reject.
    func validated() throws -> Content {
        let bank = try QuestionBankLoader.decodeBank(questions)
        let decks = try StarterDeckLoader.decode(decks)
        let exercises = try ExerciseLoader.decode(exercises, topicIds: Set(bank.topics.map(\.id)))
        return Content(bank: bank, decks: decks, exercises: exercises)
    }

    struct Content {
        let bank: QuestionBank
        let decks: StarterDeckFile
        let exercises: [Exercise]
    }
}
