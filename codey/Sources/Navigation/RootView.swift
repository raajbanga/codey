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
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack { HomeView() }
            }
            Tab("Decks", systemImage: "rectangle.stack.fill", value: AppTab.decks) {
                NavigationStack(path: $router.decksPath) { DeckLibraryView() }
            }
            Tab("Quiz", systemImage: "questionmark.bubble.fill", value: AppTab.quiz) {
                NavigationStack { QuizTopicsView() }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .fullScreenCover(item: $router.study) { request in
            StudySessionView(request: request, context: modelContext)
        }
        .fullScreenCover(item: $router.quiz) { request in
            QuizModeView(request: request, context: modelContext)
        }
        .sheet(item: $router.quizSetupTopic, onDismiss: router.presentPendingQuiz) { topic in
            QuizSetupView(topic: topic) { mode in
                router.startQuiz(QuizRequest(topic: topic, mode: mode))
            }
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
