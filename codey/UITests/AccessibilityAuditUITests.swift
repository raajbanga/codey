import XCTest

/// NFR-12 / G.3: runs the system accessibility audit (the checks Xcode's
/// Accessibility Inspector runs: contrast, labels, hit regions, Dynamic
/// Type, clipped text, traits) on every main screen, in Light and Dark.
/// Every raw finding prints one `A11Y` line; the test fails on the ones
/// that aren't known false positives (see `isKnownFalsePositive`).
@MainActor
final class AccessibilityAuditUITests: XCTestCase {
    private var app: XCUIApplication!
    private var issues: [String] = []
    private var rawCount = 0

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testAuditLight() throws {
        try runAudit(appearance: "light")
    }

    func testAuditDark() throws {
        try runAudit(appearance: "dark")
    }

    private func runAudit(appearance: String) throws {
        // Onboarding in its own launch: the NO argument keeps it on screen
        // even after Skip, so the rest of the walk relaunches without it.
        app = XCUIApplication()
        app.launchArguments = [
            "-UITestInMemoryStore", "-UITestOnboarding",
            "-hasCompletedOnboarding", "NO", "-appearance", appearance,
        ]
        app.launch()

        // Onboarding: welcome, topics, sign-in.
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        try audit("onboarding.welcome")
        next.tap()
        let topic = app.buttons["onboarding.topic.Algorithms"]
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        try audit("onboarding.topics")
        topic.tap()
        app.buttons["onboarding.continue"].tap()
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        try audit("onboarding.signIn")
        app.terminate()

        // The stubbed Ask AI client (no network) so the chat can be audited.
        app.launchArguments = ["-UITestInMemoryStore", "-UITestAskAIStub", "-appearance", appearance]
        app.launch()

        // Home and the profile sheet.
        let profile = app.buttons["home.profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        try audit("home")
        profile.tap()
        XCTAssertTrue(app.buttons["profile.done"].waitForExistence(timeout: 5))
        try audit("profile")
        app.buttons["profile.done"].tap()

        // Groups (signed out: the sign-in prompt).
        let groups = app.buttons["home.groups"]
        if groups.waitForExistence(timeout: 5) {
            groups.tap()
            sleep(1)
            try audit("groups")
            app.navigationBars.buttons.firstMatch.tap()
        }

        // Decks, deck detail, builder.
        app.tabBars.buttons["Decks"].tap()
        XCTAssertTrue(app.buttons["decks.add"].waitForExistence(timeout: 5))
        try audit("decks")
        app.buttons["decks.add"].tap()
        XCTAssertTrue(app.textFields["builder.title"].waitForExistence(timeout: 5))
        try audit("builder")
        app.navigationBars.buttons["Cancel"].firstMatch.tap()
        let discard = app.buttons["Discard Changes"]
        if discard.waitForExistence(timeout: 1) { discard.tap() }

        let tile = app.buttons["deckTile.Data Structures Essentials"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        XCTAssertTrue(app.buttons["deck.study"].waitForExistence(timeout: 5))
        try audit("deckDetail")

        // Study: front, back, then rate all 4 Easy cards for the summary.
        app.buttons["deck.study"].tap()
        let card = app.descendants(matching: .any)["study.card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        try audit("study.front")
        card.tap()
        sleep(1)
        try audit("study.back")
        card.swipeRight()
        // Rate until the summary shows: under load a swipe can land before
        // the flip finishes and is ignored (FR-16), so don't count swipes.
        // The summary takes ~1 s to appear after the last rating, so wait
        // for it before deciding there's another card to rate.
        let done = app.buttons["study.done"]
        for _ in 0..<8 {
            if done.waitForExistence(timeout: 2) { break }
            card.tap()
            sleep(1)
            card.swipeRight()
        }
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        try audit("study.summary")
        app.buttons["study.done"].tap()

        // Quiz: topics, setup, a question before and after answering.
        app.tabBars.buttons["Quiz"].tap()
        let quizTopic = app.buttons["quizTopic.Algorithms"]
        XCTAssertTrue(quizTopic.waitForExistence(timeout: 5))
        try audit("quiz.topics")

        // Coding exercises (FR-39 to FR-41): list, exercise, checked result.
        app.buttons["quiz.exercises"].tap()
        let exercise = app.buttons["exercise.ex-swift-guard"]
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        try audit("exercises.list")
        for _ in 0..<4 where !exercise.isHittable { app.swipeUp() }
        exercise.tap()
        let blank = app.textFields["exercise.blank.1"]
        XCTAssertTrue(blank.waitForExistence(timeout: 5))
        try audit("exercise")
        blank.tap()
        blank.typeText("guard")
        app.buttons["exercise.submit"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["exercise.summary"].waitForExistence(timeout: 5))
        try audit("exercise.result")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(exercise.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(quizTopic.waitForExistence(timeout: 5))

        // The row's center is on its tier chips, which are buttons of their own.
        quizTopic.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        XCTAssertTrue(app.buttons["quizSetup.start"].waitForExistence(timeout: 5))
        try audit("quiz.setup")
        app.buttons["quizSetup.start"].tap()
        let option = app.buttons["quiz.option.0"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        try audit("quiz.question")

        // Ask AI (S39): the chat with the greeting and one answer.
        app.buttons["askAI.open"].tap()
        let tutor = app.descendants(matching: .any)["askAI.message.tutor"].firstMatch
        XCTAssertTrue(tutor.waitForExistence(timeout: 10))
        try audit("askAI.chat")
        app.buttons["askAI.close"].tap()
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        sleep(1)
        try audit("quiz.answered")

        print("A11Y \(appearance) raw=\(rawCount) open=\(issues.count)")
        XCTAssertEqual(issues.count, 0, issues.joined(separator: "\n"))
    }

    /// Records every issue on the current screen instead of stopping at the
    /// first, so one run gives the full count.
    private func audit(_ screen: String) throws {
        try app.performAccessibilityAudit { issue in
            let element = issue.element.map { "\($0.elementType.rawValue) '\($0.label)' id=\($0.identifier)" } ?? "-"
            let known = Self.isKnownFalsePositive(issue)
            print("A11Y \(screen): \(issue.compactDescription) [\(element)]\(known ? " (known)" : "")")
            self.rawCount += 1
            if !known { self.issues.append("\(screen): \(issue.compactDescription) [\(element)]") }
            return true
        }
    }

    /// Findings triaged as heuristics, not defects (Sprint 3 doc, NFR-12):
    /// - Contrast: the audit samples rendered pixels, so text over the
    ///   dotted paper, glass bars, or the hidden study-card face reads as
    ///   failing (it flags black-on-paper headers). ContrastTests checks
    ///   every shipped text/background pair at 4.5:1 instead.
    /// - Text clipped: titles and descriptions truncate on purpose
    ///   (lineLimit); the layout pass checks nothing is cut off otherwise.
    /// - Dynamic Type: every font token is a text style that scales; the
    ///   check fires on text in fixed-height rows and toolbar buttons.
    /// - Hit area on non-buttons: page dots, progress bars, and counters
    ///   take no action.
    /// - Inaccessible text with no element: text left visible behind a
    ///   half-height sheet, which is modal and so hidden from VoiceOver.
    private static func isKnownFalsePositive(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        switch issue.auditType {
        case .contrast, .textClipped, .dynamicType:
            return true
        case .hitRegion:
            return issue.element?.elementType != .button
        case .elementDetection:
            return issue.element == nil
        default:
            return false
        }
    }
}
