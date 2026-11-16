import Foundation
import Testing
@testable import codey

/// FR-39: the bundled exercises.json loads and is valid; malformed files
/// are rejected whole (like QuestionBankLoader).
struct ExerciseLoaderTests {
    private let topics: Set = ["topic-swift", "topic-python"]

    @Test func bundledFileLoads() throws {
        let exercises = try ExerciseLoader.load()
        #expect((10...15).contains(exercises.count), "S31: 10 to 15 exercises")
        #expect(Set(exercises.map(\.id)).count == exercises.count)
    }

    @Test func everyBundledBlankHasAnAcceptedAnswerAndAMarker() throws {
        for exercise in try ExerciseLoader.load() {
            #expect(exercise.markerCount == exercise.blanks.count, "\(exercise.id)")
            for blank in exercise.blanks {
                #expect(!blank.accepted.isEmpty, "\(exercise.id)")
            }
        }
    }

    /// Every accepted answer passes its own blank, so no exercise is
    /// impossible to solve.
    @Test func everyBundledExerciseIsSolvable() throws {
        for exercise in try ExerciseLoader.load() {
            let answers = exercise.blanks.map { $0.accepted[0] }
            #expect(ExerciseValidator.check(answers, for: exercise).allPassed, "\(exercise.id)")
        }
    }

    @Test func bundledExercisesCoverTheCoreTopics() throws {
        let covered = Set(try ExerciseLoader.load().map(\.topicId))
        for topic in ["topic-swift", "topic-python", "topic-algorithms", "topic-data-structures"] {
            #expect(covered.contains(topic), "\(topic)")
        }
    }

    // MARK: Malformed files

    private func json(_ exercises: String, version: Int = 1) -> Data {
        Data(#"{"schemaVersion": \#(version), "exercises": [\#(exercises)]}"#.utf8)
    }

    private func exercise(id: String = "ex-a", topic: String = "topic-swift", code: String = "let x = ___", blanks: String = #"[{"accepted": ["1"]}]"#) -> String {
        #"{"id": "\#(id)", "topicId": "\#(topic)", "title": "T", "language": "swift", "prompt": "P", "code": "\#(code)", "blanks": \#(blanks), "explanation": "E"}"#
    }

    @Test func validFileDecodes() throws {
        let exercises = try ExerciseLoader.decode(json(exercise()), topicIds: topics)
        #expect(exercises.count == 1)
        #expect(exercises[0].language == .swift)
    }

    @Test func wrongSchemaVersionIsRejected() {
        #expect(throws: ExerciseLoaderError.unsupportedSchemaVersion(2)) {
            try ExerciseLoader.decode(json(exercise(), version: 2), topicIds: topics)
        }
    }

    @Test func emptyFileIsRejected() {
        #expect(throws: ExerciseLoaderError.empty) {
            try ExerciseLoader.decode(json(""), topicIds: topics)
        }
    }

    @Test func duplicateIdIsRejected() {
        #expect(throws: ExerciseLoaderError.duplicateId("ex-a")) {
            try ExerciseLoader.decode(json(exercise() + "," + exercise()), topicIds: topics)
        }
    }

    @Test func unknownTopicIsRejected() {
        #expect(throws: ExerciseLoaderError.unknownTopicId(exerciseId: "ex-a", topicId: "topic-nope")) {
            try ExerciseLoader.decode(json(exercise(topic: "topic-nope")), topicIds: topics)
        }
    }

    @Test func markerAndBlankCountsMustMatch() {
        #expect(throws: ExerciseLoaderError.blankCountMismatch(exerciseId: "ex-a", markers: 2, blanks: 1)) {
            try ExerciseLoader.decode(json(exercise(code: "___ + ___")), topicIds: topics)
        }
    }

    @Test func blankWithOnlyWhitespaceAnswersIsRejected() {
        #expect(throws: ExerciseLoaderError.noAcceptedAnswer(exerciseId: "ex-a", blank: 1)) {
            try ExerciseLoader.decode(json(exercise(blanks: #"[{"accepted": ["  "]}]"#)), topicIds: topics)
        }
    }

    @Test func unknownLanguageFailsDecoding() {
        let bad = exercise().replacingOccurrences(of: #""swift""#, with: #""cobol""#)
        #expect(throws: DecodingError.self) {
            try ExerciseLoader.decode(json(bad), topicIds: topics)
        }
    }
}
