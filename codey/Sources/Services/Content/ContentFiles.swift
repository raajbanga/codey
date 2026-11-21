import CryptoKit
import Foundation

/// The app's teaching content as its JSON files (questions-seed,
/// starter-decks, exercises, challenges), in the bundled format.
///
/// Supabase is the source (the content_* tables): the app downloads them,
/// checks them with the same loaders as the bundle, and keeps the last good
/// download in Application Support. The bundled copies are the fallback for
/// a first launch offline, demo mode, builds without backend keys, and tests.
struct ContentFiles: Equatable, Sendable {
    var questions: Data
    var decks: Data
    var exercises: Data
    /// Coding challenges (S45). Empty in a cache from before they existed;
    /// ContentSeeder then shows the bundled challenges.
    var challenges = Data()

    private static let names = (questions: "questions-seed", decks: "starter-decks", exercises: "exercises", challenges: "challenges")

    /// The copies shipped in the app.
    static func bundled(_ bundle: Bundle = .main) -> ContentFiles? {
        read { name in bundle.url(forResource: name, withExtension: "json").flatMap { try? Data(contentsOf: $0) } }
    }

    /// The last download, only when the first three files are there
    /// (challenges may be missing from an older download).
    static func cached(in directory: URL = cacheDirectory) -> ContentFiles? {
        read { name in try? Data(contentsOf: directory.appending(path: "\(name).json")) }
    }

    /// The four files from `data(name)`; nil unless the first three exist.
    private static func read(_ data: (String) -> Data?) -> ContentFiles? {
        guard let questions = data(names.questions), let decks = data(names.decks), let exercises = data(names.exercises) else {
            return nil
        }
        return ContentFiles(questions: questions, decks: decks, exercises: exercises, challenges: data(names.challenges) ?? Data())
    }

    /// What boot seeds from: the download, else the bundle. A store in
    /// memory (UI tests) always gets the bundle, so tests see known content.
    static func current(useCache: Bool = !AppLaunchOptions.usesInMemoryStore) -> ContentFiles? {
        (useCache ? cached() : nil) ?? bundled()
    }

    static var cacheDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "content", directoryHint: .isDirectory)
    }

    /// Writes every file, each atomically.
    func write(to directory: URL = Self.cacheDirectory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, data) in [(Self.names.questions, questions), (Self.names.decks, decks), (Self.names.exercises, exercises), (Self.names.challenges, challenges)] {
            try data.write(to: directory.appending(path: "\(name).json"), options: .atomic)
        }
    }

    /// SHA-256 of the files: boot skips reseeding when it matches the
    /// stamp recorded after the last seed.
    var stamp: String {
        var hasher = SHA256()
        for data in [questions, decks, exercises, challenges] { hasher.update(data: data) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Decoded and checked with the loaders; throws on anything they reject.
    func validated() throws -> Content {
        let bank = try QuestionBankLoader.decodeBank(questions)
        let decks = try StarterDeckLoader.decode(decks)
        let topicIds = Set(bank.topics.map(\.id))
        let exercises = try ExerciseLoader.decode(exercises, topicIds: topicIds)
        let challenges = try ChallengeLoader.decode(challenges, topicIds: topicIds)
        return Content(bank: bank, decks: decks, exercises: exercises, challenges: challenges)
    }

    struct Content {
        let bank: QuestionBank
        let decks: StarterDeckFile
        let exercises: [Exercise]
        var challenges: [Challenge] = []
    }
}
