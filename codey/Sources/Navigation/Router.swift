import Foundation
import Observation
import SwiftData

enum AppTab: Hashable {
    case home
    case decks
    case quiz
}

/// Deep-link destinations (widget, sign-in callbacks, Home shortcuts).
enum AppRoute: Hashable {
    case home
    case decks
    case deck(UUID)
    /// Resume (or start) studying a deck.
    case study(UUID)
    /// Quiz setup for a topic id.
    case quiz(String)
    case profile
}

/// Owns tab selection and every app-level presentation, so any screen (or a
/// deep link) can open a deck, a study session, a quiz, or the profile.
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

    func open(_ route: AppRoute, context: ModelContext) {
        switch route {
        case .home:
            tab = .home
        case .decks:
            tab = .decks
        case .deck(let id):
            tab = .decks
            decksPath = [DeckRoute(id: id)]
        case .study(let id):
            guard let deck = fetchDeck(id, context: context) else { return }
            let resumable = (try? StudyProgressSnapshot.fetch(deckId: id, context: context)) != nil
            study = StudyRequest(deck: deck, start: resumable ? .resume : .fresh(tierFilter: nil))
        case .quiz(let topicId):
            var descriptor = FetchDescriptor<Topic>(predicate: #Predicate { $0.id == topicId })
            descriptor.fetchLimit = 1
            quizSetupTopic = try? context.fetch(descriptor).first
        case .profile:
            showProfile = true
        }
    }

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

    private func fetchDeck(_ id: UUID, context: ModelContext) -> FlashcardDeck? {
        var descriptor = FetchDescriptor<FlashcardDeck>(predicate: #Predicate { $0.id == id && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
