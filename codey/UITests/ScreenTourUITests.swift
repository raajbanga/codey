import XCTest

/// Not a check: walks the main screens and attaches a screenshot of each
/// (S40 before/after, the doc's screenshot figure). Run on its own:
///   scripts/test.sh -only-testing:codeyUITests/ScreenTourUITests
/// then export with `xcrun xcresulttool export attachments`.
@MainActor
final class ScreenTourUITests: XCTestCase {
    private var app: XCUIApplication!
    private var suffix = ""

    func testTourLight() throws { try tour("light") }
    func testTourDark() throws { try tour("dark") }

    /// iPad: the same tour in landscape, where pages split into two columns.
    func testTourLandscape() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Landscape tour is for iPad")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        try tour("light", suffix: "-landscape")
    }

    private func tour(_ appearance: String, suffix: String = "") throws {
        self.suffix = suffix
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-UITestInMemoryStore", "-UITestAskAIStub", "-appearance", appearance]
        app.launch()
        let any = app.descendants(matching: .any)

        XCTAssertTrue(app.buttons["home.profile"].waitForExistence(timeout: 15))
        shot("home", appearance)
        app.swipeUp()
        app.swipeUp()
        shot("home-topics", appearance)
        app.swipeDown()
        app.swipeDown()

        app.buttons["home.profile"].tap()
        if app.buttons["profile.done"].waitForExistence(timeout: 5) {
            shot("profile", appearance)
            app.buttons["profile.done"].tap()
        }

        app.tab("Library").tap()
        if app.buttons["library.add"].waitForExistence(timeout: 5) {
            shot("library", appearance)
        }

        app.tab("Decks").tap()
        XCTAssertTrue(app.buttons["decks.add"].waitForExistence(timeout: 5))
        shot("decks", appearance)
        let tile = app.buttons["deckTile.Data Structures Essentials"].firstMatch
        if tile.waitForExistence(timeout: 5) {
            tile.tap()
            if app.buttons["deck.study"].waitForExistence(timeout: 5) {
                shot("deck-detail", appearance)
                app.buttons["deck.study"].tap()
                if any["study.card"].firstMatch.waitForExistence(timeout: 5) {
                    shot("study", appearance)
                    app.buttons["study.close"].firstMatch.tap()
                }
                app.swipeBack()
            }
        }

        app.openTopic("Swift Basics")
        let exercise = app.buttons["exercise.ex-swift-guard"]
        if exercise.waitForExistence(timeout: 5) {
            for _ in 0..<8 where !exercise.isHittable { app.swipeUp() }
            shot("exercises", appearance)
            exercise.tap()
            if app.textFields["exercise.blank.1"].waitForExistence(timeout: 5) {
                shot("exercise", appearance)
            }
            app.swipeBack()
        }
        app.swipeBack()
        app.openTopic("Algorithms")
        let topic = app.buttons["topic.play"]
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        topic.tap()
        if app.buttons["quizSetup.start"].waitForExistence(timeout: 5) {
            shot("quiz-setup", appearance)
            app.buttons["quizSetup.start"].tap()
            if app.buttons["quiz.option.0"].waitForExistence(timeout: 5) {
                shot("quiz-question", appearance)
                app.buttons["askAI.open"].tap()
                if any["askAI.message.tutor"].firstMatch.waitForExistence(timeout: 10) {
                    shot("ask-ai", appearance)
                }
            }
        }
    }



    private func shot(_ name: String, _ appearance: String) {
        sleep(1)
        // In landscape the screen's screenshot comes out rotated and cropped
        // on iPad; the window's is the right way up.
        let image = suffix.isEmpty ? app.screenshot() : app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = "\(name)-\(appearance)\(suffix)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
