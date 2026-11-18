import Foundation
import Observation

/// One code-completion exercise (FR-39, S31): a snippet with `___` blanks.
/// Plain values from the bundled exercises.json; not stored in SwiftData,
/// not synced, no XP.
struct Exercise: Decodable, Equatable, Identifiable, Hashable {
    let id: String
    let topicId: String
    let title: String
    let language: CodeLanguage
    let prompt: String
    /// The snippet; each `___` (exactly three underscores) is one blank.
    let code: String
    let blanks: [ExerciseBlank]
    let explanation: String
    /// Two hints (S45), shown one at a time; nil in older content.
    var hints: [String]?

    static let blankMarker = "___"

    /// The code as shown on screen: blank n is marked `⟦n⟧` so the answer
    /// fields below the code can say which blank they fill.
    var displayCode: String {
        let parts = code.components(separatedBy: Self.blankMarker)
        var result = parts[0]
        for (index, part) in parts.dropFirst().enumerated() {
            result += "⟦\(index + 1)⟧" + part
        }
        return result
    }

    /// Number of `___` markers in the code.
    var markerCount: Int {
        code.components(separatedBy: Self.blankMarker).count - 1
    }
}

/// One blank = one automated test case (FR-40): the answer passes if it
/// matches any accepted solution after whitespace normalization.
struct ExerciseBlank: Decodable, Equatable, Hashable {
    let accepted: [String]
}

enum ExerciseLoaderError: Error, CustomStringConvertible, Equatable {
    case fileNotFound
    case unsupportedSchemaVersion(Int)
    case empty
    case duplicateId(String)
    case unknownTopicId(exerciseId: String, topicId: String)
    case blankCountMismatch(exerciseId: String, markers: Int, blanks: Int)
    case noAcceptedAnswer(exerciseId: String, blank: Int)
    case tooManyHints(exerciseId: String)

    var description: String {
        switch self {
        case .fileNotFound:
            return "exercises.json not found in bundle"
        case .unsupportedSchemaVersion(let version):
            return "Unsupported exercises schema version: \(version)"
        case .empty:
            return "exercises.json contains no exercises"
        case .duplicateId(let id):
            return "Duplicate exercise id '\(id)'"
        case .unknownTopicId(let exerciseId, let topicId):
            return "Exercise '\(exerciseId)' references unknown topicId '\(topicId)'"
        case .blankCountMismatch(let exerciseId, let markers, let blanks):
            return "Exercise '\(exerciseId)' has \(markers) ___ markers but \(blanks) blanks"
        case .noAcceptedAnswer(let exerciseId, let blank):
            return "Exercise '\(exerciseId)' blank \(blank) has no accepted answer"
        case .tooManyHints(let exerciseId):
            return "Exercise '\(exerciseId)' has more than 3 hints"
        }
    }
}

/// Loads and validates exercises.json (like QuestionBankLoader): the file
/// either loads whole and valid or not at all.
enum ExerciseLoader {
    static let expectedSchemaVersion = 1
    private static let fileName = "exercises"

    /// The bundled exercises. Topic ids are checked against the bundled
    /// question bank's topics.
    static func load(from bundle: Bundle = .main) throws -> [Exercise] {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw ExerciseLoaderError.fileNotFound
        }
        let topicIds = Set(try QuestionBankLoader.loadBank(from: bundle).topics.map(\.id))
        return try decode(Data(contentsOf: url), topicIds: topicIds)
    }

    static func decode(_ data: Data, topicIds: Set<String>) throws -> [Exercise] {
        let file = try JSONDecoder().decode(File.self, from: data)
        guard file.schemaVersion == expectedSchemaVersion else {
            throw ExerciseLoaderError.unsupportedSchemaVersion(file.schemaVersion)
        }
        guard !file.exercises.isEmpty else { throw ExerciseLoaderError.empty }

        var seen = Set<String>()
        for exercise in file.exercises {
            guard seen.insert(exercise.id).inserted else {
                throw ExerciseLoaderError.duplicateId(exercise.id)
            }
            guard topicIds.contains(exercise.topicId) else {
                throw ExerciseLoaderError.unknownTopicId(exerciseId: exercise.id, topicId: exercise.topicId)
            }
            guard exercise.markerCount == exercise.blanks.count, !exercise.blanks.isEmpty else {
                throw ExerciseLoaderError.blankCountMismatch(
                    exerciseId: exercise.id, markers: exercise.markerCount, blanks: exercise.blanks.count
                )
            }
            guard (exercise.hints ?? []).count <= 3 else {
                throw ExerciseLoaderError.tooManyHints(exerciseId: exercise.id)
            }
            for (index, blank) in exercise.blanks.enumerated()
            where !blank.accepted.contains(where: { !ExerciseValidator.normalize($0).isEmpty }) {
                throw ExerciseLoaderError.noAcceptedAnswer(exerciseId: exercise.id, blank: index + 1)
            }
        }
        return file.exercises
    }

    private struct File: Decodable {
        let schemaVersion: Int
        let exercises: [Exercise]
    }
}

/// The exercises on screen: Library's tiles and an exercise's Next
/// Challenge / Try Another read the same list. Loaded at boot from the
/// current content (the Supabase download, else the bundle) and replaced
/// when a newer download lands, which redraws whoever reads it.
@MainActor
@Observable
final class ExerciseCatalog {
    static let shared = ExerciseCatalog()

    private(set) var result: Result<[Exercise], Error> = Result { try ExerciseLoader.load() }

    var all: [Exercise] { (try? result.get()) ?? [] }

    func replace(with exercises: [Exercise]) {
        result = .success(exercises)
    }
}

/// Which exercise "Next Challenge" and "Try Another" open (§3c).
enum ExercisePicker {
    /// The first match after `current` in bundle order (wrapping), trying in
    /// turn: unsolved in the same topic, unsolved anywhere, then any other
    /// exercise. Nil only when `current` is the only one.
    static func next(after current: Exercise, in all: [Exercise], solved: Set<String>) -> Exercise? {
        let start = (all.firstIndex(of: current) ?? -1) + 1
        let others = (all[min(start, all.count)...] + all[..<min(start, all.count)]).filter { $0.id != current.id }
        let unsolved = others.filter { !solved.contains($0.id) }
        return unsolved.first { $0.topicId == current.topicId } ?? unsolved.first ?? others.first
    }
}
