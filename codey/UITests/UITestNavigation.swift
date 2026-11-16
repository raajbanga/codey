import XCTest

extension XCUIApplication {
    /// Back to the previous page. Pages have no back button (§3b, Nov 15):
    /// the left-edge swipe goes back.
    func swipeBack() {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        let end = coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Closes a floating panel (quiz setup, Ask Codey): they have no ✕
    /// (Nov 15), so tap the dimmed screen above the card, below the status bar (a tap
    /// there goes to the system).
    func closePanel() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.09)).tap()
    }

    /// Library tab, then a topic's page (Nov 15): its Play Quiz button
    /// (`topic.play`), exercises and decks.
    func openTopic(_ title: String) {
        tabBars.buttons["Library"].tap()
        let tile = buttons["library.topic.\(title)"]
        _ = tile.waitForExistence(timeout: 15)
        for _ in 0..<4 where !tile.isHittable { swipeUp() }
        tile.tap()
    }
}
