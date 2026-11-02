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
    var quizSetupTopic: Topic?
    var showProfile = false

    /// A quiz chosen in the setup sheet, presented once the sheet is gone.
    private var pendingQuiz: QuizRequest?

    /// Called by the setup sheet's Start: close the sheet, then present.
    func startQuiz(_ request: QuizRequest) {
        if quizSetupTopic == nil {
            quiz = request
        } else {
            pendingQuiz = request
            quizSetupTopic = nil
        }
    }

    /// Setup sheet onDismiss.
    func presentPendingQuiz() {
        guard let pendingQuiz else { return }
        quiz = pendingQuiz
        self.pendingQuiz = nil
    }
}
