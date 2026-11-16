import Testing
@testable import codey

/// FR-40 / FR-41. The first four tests are the basis paths of
/// `ExerciseValidator.check(answer:accepted:)` (control-flow graph in the
/// Sprint 4 doc §18c, V(G) = 4); the rest cover normalization and the
/// per-exercise result.
struct ExerciseValidatorTests {

    // MARK: Basis paths (one test per independent path)

    /// P1: 1 → empty. Blank or whitespace-only answers never reach the loop.
    @Test(arguments: ["", "   ", "\n\t "])
    func pathEmptyAnswer(answer: String) {
        #expect(ExerciseValidator.check(answer: answer, accepted: ["map"]) == .empty)
    }

    /// P2: 1 → 2 (loop runs zero times) → 4 failed.
    @Test func pathNoAcceptedAnswers() {
        #expect(ExerciseValidator.check(answer: "map", accepted: []) == .failed)
    }

    /// P3: 1 → 2 → 3 passed (match on the first accepted answer).
    @Test func pathFirstAcceptedMatches() {
        #expect(ExerciseValidator.check(answer: "map", accepted: ["map", "compactMap"]) == .passed)
    }

    /// P4: 1 → 2 → 3 (no match) → 2 → 4 failed (loop exhausted).
    @Test func pathNoMatchAfterLoop() {
        #expect(ExerciseValidator.check(answer: "filter", accepted: ["map", "compactMap"]) == .failed)
    }

    /// The loop also finds a later accepted answer (3 after a false 3).
    @Test func laterAcceptedAnswerMatches() {
        #expect(ExerciseValidator.check(answer: "1 + mid", accepted: ["mid + 1", "1 + mid"]) == .passed)
    }

    // MARK: Normalization

    @Test(arguments: [
        ("mid + 1", "mid+1"),
        ("  mid  +   1 ", "mid+1"),
        ("return x", "return x"),
        ("a\n  b", "a b"),
        ("items.append( x )", "items.append(x)"),
        ("<=", "<="),
    ])
    func normalization(input: String, expected: String) {
        #expect(ExerciseValidator.normalize(input) == expected)
    }

    @Test func spacingAroundOperatorsDoesNotMatter() {
        #expect(ExerciseValidator.check(answer: "mid+1", accepted: ["mid + 1"]) == .passed)
    }

    @Test func spacingBetweenWordsStillMatters() {
        #expect(ExerciseValidator.check(answer: "returnx", accepted: ["return x"]) == .failed)
    }

    @Test func answersAreCaseSensitive() {
        #expect(ExerciseValidator.check(answer: "Map", accepted: ["map"]) == .failed)
    }

    // MARK: Whole exercise

    private let twoBlanks = Exercise(
        id: "ex-test", topicId: "topic-swift", title: "T", language: .swift, prompt: "P",
        code: "___ b != 0 ___ { return nil }",
        blanks: [ExerciseBlank(accepted: ["guard"]), ExerciseBlank(accepted: ["else"])],
        explanation: "E"
    )

    @Test func onePassFailResultPerBlank() {
        let result = ExerciseValidator.check(["guard", "then"], for: twoBlanks)
        #expect(result.blanks == [.passed, .failed])
        #expect(result.passedCount == 1)
        #expect(!result.allPassed)
    }

    @Test func allBlanksCorrectPasses() {
        let result = ExerciseValidator.check([" guard", "else "], for: twoBlanks)
        #expect(result.allPassed)
    }

    @Test func missingAnswersCountAsEmpty() {
        #expect(ExerciseValidator.check(["guard"], for: twoBlanks).blanks == [.passed, .empty])
    }

    @Test func displayCodeNumbersTheBlanks() {
        #expect(twoBlanks.displayCode == "⟦1⟧ b != 0 ⟦2⟧ { return nil }")
    }
}
