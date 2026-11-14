import SwiftData
import SwiftUI

/// App shell (D8): Home | Decks | Quiz with a Liquid Glass tab bar that
/// shrinks on scroll, plus the app-level sheets/covers. Study and Quiz are
/// full-screen covers (focus mode), so the bar never covers their controls.
/// Every study session and quiz is presented from here, via the Router.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var router = Router()

    var body: some View {
        TabView(selection: $router.tab) {
            Tab("Home", image: "icon-home", value: AppTab.home) {
                NavigationStack { HomeView() }
            }
            Tab("Decks", image: "icon-cards", value: AppTab.decks) {
                NavigationStack(path: $router.decksPath) { DeckLibraryView() }
            }
            Tab("Quiz", image: "icon-quiz", value: AppTab.quiz) {
                NavigationStack { QuizTopicsView() }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        // Ink blue for the selected tab instead of the system blue.
        .tint(CodeyColor.brand)
        // Study and Quiz covers show their own banner (FR-35).
        .badgeBanner(isActive: router.study == nil && router.quiz == nil)
        .fullScreenCover(item: $router.study) { request in
            ViewModelHost {
                StudySessionViewModel(deck: request.deck, start: request.start, context: modelContext)
            } content: {
                StudySessionView(viewModel: $0)
            }
        }
        .fullScreenCover(item: $router.quiz) { request in
            ViewModelHost {
                QuizViewModel(topic: request.topic, mode: request.mode, context: modelContext)
            } content: {
                QuizModeView(viewModel: $0)
            }
        }
        // Above the tab bar, so the dimmed page covers it too.
        .floatingPanel(item: $router.quizSetupTopic) { topic in
            QuizSetupView(topic: topic) { mode in
                router.startQuiz(QuizRequest(topic: topic, mode: mode))
            }
        }
        .floatingPanel(item: $router.askAI, fillsHeight: true) { session in
            AskAIChatView(session: session)
        }
        .sheet(isPresented: $router.showProfile) {
            ProfileSheet()
        }
        .environment(router)
    }
}

#Preview {
    let container = ModelContainerFactory.makePreview()
    RootView()
        .modelContainer(container)
        .environment(BackendFacade.localOnly(context: container.mainContext))
}
