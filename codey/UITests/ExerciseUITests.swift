import XCTest

/// FR-39 to FR-41 end to end (system test ST-05 in the Sprint 4 doc §18e):
/// Quiz tab → Coding Exercises → "Exit early with guard" → one right and
/// one wrong blank → per-blank pass/fail → Try Again → both right → all
/// tests pass. Screenshots are attached to the result bundle.
@MainActor
final class ExerciseUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestInMemoryStore"]
        app.launch()
    }

    func testSolveGuardExercise() throws {
        let quizTab = app.tabBars.buttons["Quiz"]
        XCTAssertTrue(quizTab.waitForExistence(timeout: 15))
        quizTab.tap()

        let entry = app.buttons["quiz.exercises"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        snapshot("quiz-tab")
        entry.tap()

        let exercise = app.buttons["exercise.ex-swift-guard"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        snapshot("exercise-list")
        hittable(exercise).tap()

        // One right, one wrong: each blank gets its own result (FR-41).
        answer(1, "guard")
        answer(2, "then")
        snapshot("exercise-filled")
        check(["guard", "then"])

        XCTAssertTrue(app.descendants(matching: .any)["exercise.summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(chip(1).label.contains("Passed"), chip(1).label)
        XCTAssertTrue(chip(2).label.contains("Failed"), chip(2).label)
        XCTAssertTrue(app.staticTexts["1 of 2 tests passed"].exists)
        snapshot("exercise-result-partial")

        // Try again with both right; spacing around the answer is ignored.
        hittable(app.buttons["exercise.retry"]).tap()
        answer(1, " guard ")
        answer(2, "else")
        check([" guard ", "else"])
        XCTAssertTrue(app.staticTexts["All 2 tests passed"].waitForExistence(timeout: 5))
        XCTAssertTrue(chip(2).label.contains("Passed"), chip(2).label)
        snapshot("exercise-result-pass")
    }

    /// Types into a blank and checks the field took every character (a
    /// loaded Simulator can drop the first keystrokes while focus moves),
    /// retyping if not.
    private func answer(_ blank: Int, _ text: String) {
        let field = hittable(app.textFields["exercise.blank.\(blank)"])
        // Don't tap a field that's already right: the tap can put the caret
        // mid-word, and the next keystroke lands there.
        for _ in 0..<3 {
            let raw = field.value as? String ?? ""
            let current = raw == field.placeholderValue ? "" : raw
            if current == text { break }
            field.tap()
            if !current.isEmpty {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
            }
            field.typeText(text)
        }
        XCTAssertEqual(field.value as? String, text)
    }

    /// Hides the keyboard (Return on the last blank clears focus), checks
    /// every blank still holds its answer, then taps Check. A busy Simulator
    /// can drop a keystroke even after the field showed it (see
    /// DeckBuilderUITests.enter), and Check sits under the keyboard on
    /// small phones.
    private func check(_ expected: [String]) {
        for _ in 0..<3 {
            if app.keyboards.firstMatch.exists {
                app.typeText("\n")
                let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.firstMatch)
                wait(for: [gone], timeout: 5)
            }
            let wrong = expected.indices.filter {
                app.textFields["exercise.blank.\($0 + 1)"].value as? String != expected[$0]
            }
            if wrong.isEmpty { break }
            for index in wrong { answer(index + 1, expected[index]) }
        }
        hittable(app.buttons["exercise.submit"]).tap()
    }

    private func chip(_ blank: Int) -> XCUIElement {
        app.descendants(matching: .any)["exercise.result.\(blank)"].firstMatch
    }

    /// Scrolls until the element can be tapped (small phones, keyboard up).
    private func hittable(_ element: XCUIElement) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<4 where !element.isHittable {
            app.swipeUp()
        }
        return element
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
