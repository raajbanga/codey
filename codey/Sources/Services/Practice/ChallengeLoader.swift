import Foundation
import Observation

/// One coding challenge (S45, FR-69): a LeetCode-style problem the student
/// solves by writing a whole function, run on the Codey runner through the
/// run-challenge Edge Function. Plain values from challenges.json (the
/// Supabase download, else the bundle). Only example tests are here: hidden
/// tests never reach the app (FR-72).
struct Challenge: Codable, Equatable, Identifiable, Hashable {
    struct Param: Codable, Equatable, Hashable {
        let name: String
        let type: String
    }

    /// One example test, already formatted for display.
    struct Example: Codable, Equatable, Hashable {
        /// "nums = [2,7,11,15], target = 9"
        let input: String
        /// "[0,1]"
        let output: String
        let explanation: String?
    }

    let id: String
    let topicId: String
    let title: String
    let difficulty: Difficulty
    /// Markdown.
    let statement: String
    let constraints: [String]
    let hints: [String]
    let functionName: String
    let params: [Param]
    let returnType: String
    let comparator: String
    /// Markdown, shown after an accepted submission.
    let editorial: String
    let starters: [String: String]
    let examples: [Example]

    func starter(for language: CodeLanguage) -> String { starters[language.rawValue] ?? "" }

    /// The languages this challenge has starter code for, in the app's order.
    var languages: [CodeLanguage] { CodeLanguage.allCases.filter { starters[$0.rawValue] != nil } }
}

enum ChallengeLoaderError: Error, CustomStringConvertible, Equatable {
    case fileNotFound
    case unsupportedSchemaVersion(Int)
    case duplicateId(String)
    case badId(String)
    case unknownTopicId(challengeId: String, topicId: String)
    case missingStarter(challengeId: String)
    case noExamples(challengeId: String)
    case tooManyHints(challengeId: String)

    var description: String {
        switch self {
        case .fileNotFound: "challenges.json not found in bundle"
        case .unsupportedSchemaVersion(let version): "Unsupported challenges schema version: \(version)"
        case .duplicateId(let id): "Duplicate challenge id '\(id)'"
        case .badId(let id): "Challenge id '\(id)' must start with ch-"
        case .unknownTopicId(let id, let topic): "Challenge '\(id)' references unknown topicId '\(topic)'"
        case .missingStarter(let id): "Challenge '\(id)' has no starter code"
        case .noExamples(let id): "Challenge '\(id)' has no example tests"
        case .tooManyHints(let id): "Challenge '\(id)' has more than 3 hints"
        }
    }
}

/// Loads and checks challenges.json (like ExerciseLoader): the file loads
/// whole and valid or not at all. Empty data is "no challenges" (a cache
/// from before challenges existed).
enum ChallengeLoader {
    static let expectedSchemaVersion = 1
    static let fileName = "challenges"

    static func decode(_ data: Data, topicIds: Set<String>) throws -> [Challenge] {
        guard !data.isEmpty else { return [] }
        let file = try JSONDecoder().decode(File.self, from: data)
        guard file.schemaVersion == expectedSchemaVersion else {
            throw ChallengeLoaderError.unsupportedSchemaVersion(file.schemaVersion)
        }
        var seen = Set<String>()
        for challenge in file.challenges {
            guard challenge.id.hasPrefix("ch-") else { throw ChallengeLoaderError.badId(challenge.id) }
            guard seen.insert(challenge.id).inserted else { throw ChallengeLoaderError.duplicateId(challenge.id) }
            guard topicIds.contains(challenge.topicId) else {
                throw ChallengeLoaderError.unknownTopicId(challengeId: challenge.id, topicId: challenge.topicId)
            }
            guard !challenge.languages.isEmpty else { throw ChallengeLoaderError.missingStarter(challengeId: challenge.id) }
            guard !challenge.examples.isEmpty else { throw ChallengeLoaderError.noExamples(challengeId: challenge.id) }
            guard challenge.hints.count <= 3 else { throw ChallengeLoaderError.tooManyHints(challengeId: challenge.id) }
        }
        return file.challenges
    }

    struct File: Codable {
        var schemaVersion = 1
        let challenges: [Challenge]
    }
}

/// The challenges on screen (Library tiles, Next Challenge), replaced when
/// a newer download lands, like ExerciseCatalog.
@MainActor
@Observable
final class ChallengeCatalog {
    static let shared = ChallengeCatalog()

    private(set) var all: [Challenge] = []

    func replace(with challenges: [Challenge]) {
        all = challenges
    }

    /// The next unsolved challenge after `current` (same rules as drills).
    func next(after current: Challenge, solved: Set<String>) -> Challenge? {
        let start = (all.firstIndex(of: current) ?? -1) + 1
        let others = (all[min(start, all.count)...] + all[..<min(start, all.count)]).filter { $0.id != current.id }
        return others.first { !solved.contains($0.id) } ?? others.first
    }
}

/// The student's code per challenge and language (FR-73): small files in
/// Application Support, never synced (they're personal and can be large).
enum ChallengeDrafts {
    static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "challenge-drafts", directoryHint: .isDirectory)
    }

    private static func url(_ id: String, _ language: CodeLanguage, in directory: URL) -> URL {
        directory.appending(path: "\(id).\(language.rawValue).txt")
    }

    static func load(_ id: String, language: CodeLanguage, in directory: URL = directory) -> String? {
        try? String(contentsOf: url(id, language, in: directory), encoding: .utf8)
    }

    static func save(_ code: String, id: String, language: CodeLanguage, in directory: URL = directory) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try code.write(to: url(id, language, in: directory), atomically: true, encoding: .utf8)
        } catch {
            // A lost draft is not worth interrupting the student for.
        }
    }

    static func remove(_ id: String, language: CodeLanguage, in directory: URL = directory) {
        try? FileManager.default.removeItem(at: url(id, language, in: directory))
    }

    static func removeAll(in directory: URL = directory) {
        try? FileManager.default.removeItem(at: directory)
    }
}
