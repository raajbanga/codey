import XCTest

/// Ask AI end to end with the stubbed client (`-UITestAskAIStub`, no
/// network): open the chat on a quiz question, get the greeting, ask, get
/// an explanation; the next question starts a fresh chat (FR-67/68). Then
/// the button on a coding exercise.
@MainActor
final class AskAIUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestInMemoryStore", "-UITestAskAIStub"]
        app.launch()
    }

    func testAskAIOnQuizQuestionResetsOnNextQuestion() throws {
        app.tabBars.buttons["Quiz"].tap()
        let topic = app.buttons["quizTopic.Algorithms"]
        XCTAssertTrue(topic.waitForExistence(timeout: 15))
        // The row's center is on its tier chips, which are buttons of their own.
        topic.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        XCTAssertTrue(app.buttons["quizSetup.start"].waitForExistence(timeout: 5))
        app.buttons["quizSetup.start"].tap()

        openChat()
        XCTAssertEqual(tutorMessages.count, 1, "the first reply is only the greeting")
        snapshot("askai-greeting")

        let input = app.textViews["askAI.input"].exists ? app.textViews["askAI.input"] : app.textFields["askAI.input"]
        input.tap()
        input.typeText("Why does this work?")
        app.buttons["askAI.send"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["askAI.message.student"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForTutorMessages(2))
        snapshot("askai-answer")

        // Same question: the chat is kept.
        app.buttons["askAI.close"].tap()
        openChat()
        XCTAssertEqual(tutorMessages.count, 2)
        app.buttons["askAI.close"].tap()

        // Next question: a fresh chat.
        let option = app.buttons["quiz.option.0"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        app.buttons["quiz.next"].tap()
        openChat()
        XCTAssertEqual(tutorMessages.count, 1)
        XCTAssertFalse(app.descendants(matching: .any)["askAI.message.student"].exists)
    }

    func testAskAIOnCodingExercise() throws {
        app.tabBars.buttons["Quiz"].tap()
        let entry = app.buttons["Exercises"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        entry.tap()
        let exercise = app.buttons["exercise.ex-swift-guard"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        for _ in 0..<4 where !exercise.isHittable { app.swipeUp() }
        exercise.tap()
        openChat()
        XCTAssertEqual(tutorMessages.count, 1)
    }

    func testNoAskAIButtonOutsideQuizAndExercises() throws {
        XCTAssertTrue(app.buttons["home.profile"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["askAI.open"].exists)
        app.tabBars.buttons["Decks"].tap()
        XCTAssertTrue(app.buttons["decks.add"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["askAI.open"].exists)
    }

    // MARK: Helpers

    private var tutorMessages: XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "askAI.message.tutor")
    }

    private func openChat() {
        let open = app.buttons["askAI.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(waitForTutorMessages(1), "greeting")
    }

    private func waitForTutorMessages(_ count: Int) -> Bool {
        let predicate = NSPredicate(format: "count >= %d", count)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: tutorMessages)
        return XCTWaiter.wait(for: [expectation], timeout: 10) == .completed
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
