import XCTest

extension XCUIApplication {
    /// A tab's button. iPhone draws the tab bar at the bottom (a TabBar);
    /// iPadOS draws it floating at the top, where its items are plain
    /// buttons outside any TabBar, so fall back to the button by label.
    /// Waits for it: right after `swipeBack()` the tab bar is still coming
    /// back, and tapping then failed (CI flake, testAuditDark).
    func tab(_ name: String, timeout: TimeInterval = 5) -> XCUIElement {
        let bottom = tabBars.buttons[name]
        let top = buttons[name].firstMatch
        let deadline = Date.now.addingTimeInterval(timeout)
        repeat {
            if bottom.exists && bottom.isHittable { return bottom }
            if top.exists && top.isHittable { return top }
            RunLoop.current.run(until: .now.addingTimeInterval(0.1))
        } while Date.now < deadline
        return bottom.exists ? bottom : top
    }

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
    /// Pushed pages (deck detail, a topic's page) hide the tab bar, so swipe
    /// back until it shows before tapping the tab.
    func openTopic(_ title: String) {
        for _ in 0..<4 where !tab("Library").waitForExistence(timeout: 2) { swipeBack() }
        tab("Library").tap()
        let tile = buttons["library.topic.\(title)"]
        _ = tile.waitForExistence(timeout: 15)
        for _ in 0..<4 where !tile.isHittable { swipeUp() }
        tile.tap()
    }
}
