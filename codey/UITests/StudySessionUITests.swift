import XCTest

/// Stage 5: study a starter deck (flip, rate), leave, and resume.
final class StudySessionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
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
        XCTAssertTrue(app.staticTexts["1 / 4"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["study.rate.good"].exists, "ratings appear only after reveal (FR-16)")

        app.buttons["study.reveal"].tap()
        let good = app.buttons["study.rate.good"]
        XCTAssertTrue(good.waitForExistence(timeout: 3))
        good.tap()
        XCTAssertTrue(app.staticTexts["2 / 4"].waitForExistence(timeout: 3))

        // Tap the card itself to flip, then rate Again (re-queued once).
        app.descendants(matching: .any)["study.card"].firstMatch.tap()
        let again = app.buttons["study.rate.again"]
        XCTAssertTrue(again.waitForExistence(timeout: 3))
        again.tap()
        XCTAssertTrue(app.staticTexts["3 / 5"].waitForExistence(timeout: 3))

        app.buttons["study.close"].tap()
        let resume = app.buttons["deck.continue"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        XCTAssertTrue(resume.label.contains("3/5"))
        resume.tap()
        XCTAssertTrue(app.staticTexts["3 / 5"].waitForExistence(timeout: 5))
    }
}
