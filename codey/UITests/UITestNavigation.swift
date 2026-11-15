import XCTest

extension XCUIApplication {
    /// Back to the previous page. Pages have no back button (§3b, Nov 15):
    /// the left-edge swipe goes back.
    func swipeBack() {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        let end = coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
}
