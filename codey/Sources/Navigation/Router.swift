import Foundation
import Observation

/// The three tabs (D8 r3).
enum AppTab: Hashable {
    case home
    case decks
    case quiz
}

/// Owns tab selection and every app-level presentation, so any screen can
/// open a deck, a study session, a quiz, or the profile.
@MainActor
@Observable
final class Router {
    var tab: AppTab = .home
    var decksPath: [DeckRoute] = []

    var study: StudyRequest?
    var quiz: QuizRequest?
    /// Quiz setup, shown as a FloatingPanel at the root (S40).
    var quizSetupTopic: Topic?
    var showProfile = false
    /// Ask AI on a coding exercise (S39), in a root FloatingPanel so the
    /// dimmed page covers the bars. The quiz cover hosts its own.
    var askAI: AskAISession?

    /// The setup panel's Start: close the panel and present the quiz. The
    /// panel is an overlay, not a sheet, so nothing has to wait for it.
    func startQuiz(_ request: QuizRequest) {
        quizSetupTopic = nil
        quiz = request
    }
}
