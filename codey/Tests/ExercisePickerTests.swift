import Testing
@testable import codey

/// §3c: Next Challenge / Try Another pick an unsolved exercise in the same
/// topic first, then any unsolved one, then any other one.
struct ExercisePickerTests {
    private static func exercise(_ id: String, topic: String) -> Exercise {
        Exercise(
            id: id, topicId: topic, title: id, language: .swift, prompt: "", code: "___",
            blanks: [ExerciseBlank(accepted: ["x"])], explanation: ""
        )
    }

    private let all = [
        exercise("a1", topic: "a"), exercise("b1", topic: "b"),
        exercise("a2", topic: "a"), exercise("b2", topic: "b"), exercise("a3", topic: "a"),
    ]

    @Test func prefersUnsolvedInTheSameTopic() {
        #expect(ExercisePicker.next(after: all[0], in: all, solved: [])?.id == "a2")
    }

    @Test func skipsSolvedAndWrapsAround() {
        let next = ExercisePicker.next(after: all[4], in: all, solved: ["a2"])
        #expect(next?.id == "a1")
    }

    @Test func fallsBackToAnotherTopicWhenTheTopicIsDone() {
        let next = ExercisePicker.next(after: all[0], in: all, solved: ["a2", "a3", "b1"])
        #expect(next?.id == "b2")
    }

    @Test func fallsBackToTheNextOneWhenEverythingIsSolved() {
        let next = ExercisePicker.next(after: all[1], in: all, solved: Set(all.map(\.id)))
        #expect(next?.id == "a2")
    }

    @Test func neverReturnsTheCurrentExercise() {
        #expect(ExercisePicker.next(after: all[0], in: [all[0]], solved: []) == nil)
    }
}
