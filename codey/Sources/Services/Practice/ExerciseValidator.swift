import Foundation

/// Result of one blank's test case (FR-41).
enum BlankResult: Equatable {
    case passed
    case failed
    /// Nothing entered; counts as a failed test case.
    case empty

    var isPassed: Bool { self == .passed }
}

/// Result of submitting an exercise: one test case per blank.
struct ExerciseResult: Equatable {
    let blanks: [BlankResult]

    var passedCount: Int { blanks.filter(\.isPassed).count }
    var allPassed: Bool { !blanks.isEmpty && passedCount == blanks.count }
}

/// Checks code-completion answers (FR-40). Pure: no state, no SwiftData, no
/// code execution (S31). `check(answer:accepted:)` is the method whose
/// control-flow graph drives the basis-path tests (Sprint 4 doc §18c, S36).
enum ExerciseValidator {
    /// Runs every blank's test case. A missing answer counts as empty.
    static func check(_ answers: [String], for exercise: Exercise) -> ExerciseResult {
        ExerciseResult(blanks: exercise.blanks.indices.map { index in
            check(answer: index < answers.count ? answers[index] : "", accepted: exercise.blanks[index].accepted)
        })
    }

    /// One test case. Control flow (V(G) = 4):
    ///   1. empty after normalization → .empty
    ///   2. loop over the accepted answers (may run zero times)
    ///   3. an accepted answer matches → .passed
    ///   4. loop ends without a match → .failed
    static func check(answer: String, accepted: [String]) -> BlankResult {
        let given = normalize(answer)
        if given.isEmpty {
            return .empty
        }
        for option in accepted {
            if normalize(option) == given {
                return .passed
            }
        }
        return .failed
    }

    /// Whitespace normalization: trims, collapses every run of whitespace to
    /// one space, then drops spaces next to punctuation or operators, so
    /// `mid+1`, `mid + 1` and ` mid  +  1 ` are equal while `return x` and
    /// `returnx` are not. Case-sensitive, because code is.
    static func normalize(_ text: String) -> String {
        let words = text.split(whereSeparator: \.isWhitespace)
        var result = ""
        for word in words {
            if let last = result.last, let first = word.first, isWordCharacter(last), isWordCharacter(first) {
                result.append(" ")
            }
            result += word
        }
        return result
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
