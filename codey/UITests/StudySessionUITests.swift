import XCTest

/// Stage 5: study a starter deck (tap to flip, swipe to rate), leave, and resume.
@MainActor
final class StudySessionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestInMemoryStore"]
        app.launch()
    }

    func testStudyRateCloseAndResume() throws {
        let decksTab = app.tabBars.buttons["Decks"]
        XCTAssertTrue(decksTab.waitForExistence(timeout: 15))
        decksTab.tap()

        let tile = app.buttons["deckTile.Data Structures Essentials"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()

        let study = app.buttons["deck.study"]
        XCTAssertTrue(study.waitForExistence(timeout: 5))
        study.tap()

        // New learner: only the 4 Easy cards are unlocked (D9).
        // The bar shows ticks only; the count is its VoiceOver label (§3b).
        let counter = app.descendants(matching: .any)["study.counter"].firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 5))
        XCTAssertEqual(counter.label, "Card 1 of 4")
        let card = app.descendants(matching: .any)["study.card"].firstMatch

        // Swiping before the reveal does nothing (FR-16).
        card.swipeRight()
        XCTAssertEqual(counter.label, "Card 1 of 4")

        // Tap to flip, swipe right = Good.
        XCTAssertTrue(flipAndRate(card, counter: counter, to: "Card 2 of 4") { $0.swipeRight() })

        // Flip, swipe left = Again: re-queued once and announced as a repeat
        // instead of growing the total (S19).
        XCTAssertTrue(flipAndRate(card, counter: counter, to: "Card 3 of 4, 1 repeat added") { $0.swipeLeft() })

        app.buttons["study.close"].tap()
        let resume = app.buttons["deck.continue"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        // The button says Continue; the position is the counter's (S41).
        XCTAssertTrue(resume.label.contains("Continue"))
        resume.tap()
        XCTAssertTrue(counter.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel(counter, "Card 3 of 4, 1 repeat added"))
    }

    /// Flips the card, waits for the answer side (its swipe hint), then
    /// swipes. A swipe that lands while the flip is still animating is
    /// ignored, so one that changed nothing is tried once more.
    private func flipAndRate(_ card: XCUIElement, counter: XCUIElement, to label: String, swipe: (XCUIElement) -> Void) -> Bool {
        let answerSide = app.staticTexts["Good"].firstMatch
        card.tap()
        if !answerSide.waitForExistence(timeout: 3) { card.tap() }
        guard answerSide.waitForExistence(timeout: 3) else { return false }
        for _ in 0..<2 {
            swipe(card)
            if waitForLabel(counter, label, timeout: 3) { return true }
        }
        return false
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
