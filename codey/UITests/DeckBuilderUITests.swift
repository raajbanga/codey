import XCTest

/// 3.4: create a deck with 2 cards (one with a Python snippet) and see it in
/// the library as "Saved locally".
@MainActor
final class DeckBuilderUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
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
        enter("UI Test Deck", into: title)

        // Card 1: prompt + answer.
        fill(prompt: "What does `let` declare?", answer: "A constant.")

        // Card 2: prompt + Python snippet + answer, added from the top
        // bar's + (§3b: no mini-card strip).
        app.buttons["builder.addCard"].tap()
        hittable(app.textViews.matching(NSPredicate(format: "label == 'Prompt'"))).tap()
        app.typeText("What prints?")
        // The keyboard covers "Add code" on smaller phones; close it the
        // way a user would, by tapping the bar's deck name.
        dismissKeyboard()
        hittable(app.buttons.matching(identifier: "card.addCode")).tap()

        let language = hittable(app.buttons.matching(identifier: "card.language"))
        language.tap()
        app.buttons["Python"].firstMatch.tap()

        let editor = hittable(app.descendants(matching: .any).matching(identifier: "card.codeEditor"))
        editor.tap()
        app.typeText("print(1)")

        flipCard()
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

    /// A guest deck has never synced, so deleting it is a hard delete. The
    /// detail screen must survive its own pop animation without reading it.
    func testDeleteUnsyncedDeckFromDetail() throws {
        let decksTab = app.tabBars.buttons["Decks"]
        XCTAssertTrue(decksTab.waitForExistence(timeout: 15))
        decksTab.tap()

        app.buttons["decks.add"].tap()
        let title = app.textFields["builder.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        enter("Doomed Deck", into: title)
        fill(prompt: "Q?", answer: "A.")
        app.buttons["builder.save"].tap()

        let tile = app.buttons["deckTile.Doomed Deck"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15))
        tile.tap()

        // Delete sits in the deck's ⋯ menu; the menu item and the
        // confirmation's button share the label.
        let more = app.buttons["deck.actions"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let menuItem = app.buttons["Delete Deck"].firstMatch
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5))
        menuItem.tap()
        let confirm = app.buttons["Delete Deck"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(app.buttons["decks.add"].waitForExistence(timeout: 10))
        XCTAssertTrue(tile.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Types into a text field and checks it took: a busy Simulator can drop
    /// keystrokes ("UI Test Deck" was once saved as "UIest Dec"), and the
    /// tile lookup by title then fails 15 s later with no hint why.
    private func enter(_ text: String, into field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<3 {
            field.tap()
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 5)
            let current = field.value as? String ?? ""
            if !current.isEmpty, current != field.placeholderValue {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
            }
            field.typeText(text)
            if field.value as? String == text { return }
        }
        XCTFail("\(field) holds \"\(field.value as? String ?? "")\", not \"\(text)\"", file: file, line: line)
    }

    private func fill(prompt: String, answer: String) {
        hittable(app.textViews.matching(NSPredicate(format: "label == 'Prompt'"))).tap()
        app.typeText(prompt)
        flipCard()
        hittable(app.textViews.matching(NSPredicate(format: "label == 'Answer'"))).tap()
        app.typeText(answer)
        flipCard()
    }

    private func dismissKeyboard() {
        app.staticTexts["builder.barTitle"].tap()
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
    }

    /// Turns the card over (prompt ⇄ answer).
    private func flipCard() {
        hittable(app.buttons.matching(identifier: "card.flip")).tap()
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
