import XCTest

/// 3.4: create a deck with 2 cards (one with a Python snippet) and see it in
/// the library as "Saved locally".
final class DeckBuilderUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestInMemoryStore"]
        app.launch()
    }

    func testCreateDeckWithPythonSnippet() throws {
        let decksTab = app.tabBars.buttons["Decks"]
        XCTAssertTrue(decksTab.waitForExistence(timeout: 15))
        decksTab.tap()

        app.buttons["decks.add"].tap()

        let title = app.textFields["builder.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("UI Test Deck")

        // Card 1: prompt + answer.
        fill(prompt: "What does `let` declare?", answer: "A constant.")

        // Card 2: prompt + Python snippet + answer.
        app.buttons["strip.addCard"].tap()
        hittable(app.textViews.matching(NSPredicate(format: "label == 'Prompt'"))).tap()
        app.typeText("What prints?")
        // The keyboard covers "Add code" on smaller phones; close it the
        // way a user would, with the builder's keyboard "Done" button.
        dismissKeyboard()
        hittable(app.buttons.matching(identifier: "card.addCode")).tap()

        let language = hittable(app.buttons.matching(identifier: "card.language"))
        language.tap()
        app.buttons["Python"].firstMatch.tap()

        let editor = hittable(app.descendants(matching: .any).matching(identifier: "card.codeEditor"))
        editor.tap()
        app.typeText("print(1)")

        switchSide(to: "Back")
        hittable(app.textViews.matching(NSPredicate(format: "label == 'Answer'"))).tap()
        app.typeText("1")

        app.buttons["builder.save"].tap()

        // The sheet's dismissal can take a few seconds on a busy Simulator
        // (e.g. right after the accessibility audit); same budget as launch.
        let tile = app.buttons["deckTile.UI Test Deck"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15))
        XCTAssertTrue(tile.staticTexts["Saved locally"].exists || tile.label.contains("Saved locally"))
        XCTAssertTrue(tile.label.contains("2 cards"))
    }

    private func fill(prompt: String, answer: String) {
        hittable(app.textViews.matching(NSPredicate(format: "label == 'Prompt'"))).tap()
        app.typeText(prompt)
        switchSide(to: "Back")
        hittable(app.textViews.matching(NSPredicate(format: "label == 'Answer'"))).tap()
        app.typeText(answer)
        switchSide(to: "Front")
    }

    private func dismissKeyboard() {
        let done = app.toolbars.buttons["Done"]
        if done.waitForExistence(timeout: 2) { done.tap() }
    }

    private func switchSide(to side: String) {
        hittable(app.segmentedControls.matching(identifier: "card.side")).buttons[side].tap()
    }

    /// The pager keeps neighbors in the hierarchy; act on the visible one.
    private func hittable(_ query: XCUIElementQuery, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let deadline = Date().addingTimeInterval(5)
        repeat {
            if let element = query.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) {
                return element
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline
        XCTFail("No hittable element for \(query)", file: file, line: line)
        return query.firstMatch
    }
}
