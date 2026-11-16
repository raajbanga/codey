import SwiftData
import SwiftUI

/// App shell (D8, S41): Play | Decks | Library with a Liquid Glass tab bar that
/// shrinks on scroll (the only system-drawn control), plus the app-level sheets/covers. Study and Quiz are
/// full-screen covers (focus mode), so the bar never covers their controls.
/// Every study session and quiz is presented from here, via the Router.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var router = Router()
    @Query private var profiles: [UserProfile]

    /// The avatar's color as the app accent (S42); nil keeps slate and ink.
    private var appHue: CodeyColor.TopicHue? {
        let color = ProfileAvatar.color(for: profiles.first?.avatarId)
        return color == .slate ? nil : color.hue
    }

    var body: some View {
        TabView(selection: $router.tab) {
            Tab("Play", image: "icon-controller", value: AppTab.home) {
                NavigationStack { HomeView() }
            }
            Tab("Decks", image: "icon-cards", value: AppTab.decks) {
                NavigationStack(path: $router.decksPath) { DeckLibraryView() }
            }
            Tab("Library", image: "icon-layers", value: AppTab.library) {
                NavigationStack { LibraryView() }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        // Ink blue (or the avatar's color) for the selected tab instead of
        // the system blue.
        .tint(appHue?.fill ?? CodeyColor.brand)
        // Study and Quiz covers show their own banner (FR-35).
        .badgeBanner(isActive: router.study == nil && router.quiz == nil)
        .fullScreenCover(item: $router.study) { request in
            ViewModelHost {
                StudySessionViewModel(deck: request.deck, start: request.start, context: modelContext)
            } content: {
                StudySessionView(viewModel: $0)
            }
            .codeyOverlayHost()
        }
        .fullScreenCover(item: $router.quiz) { request in
            ViewModelHost {
                QuizViewModel(topic: request.topic, mode: request.mode, context: modelContext)
            } content: {
                QuizModeView(viewModel: $0)
            }
            .codeyOverlayHost()
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
        // Our dropdowns, tips and dialogs draw here, above the tab bar and
        // the floating panels; each sheet and cover has its own layer.
        .codeyOverlayHost()
        .sheet(isPresented: $router.showProfile) {
            ProfileSheet()
        }
        .environment(router)
        .environment(\.appHue, appHue)
    }
}

#Preview {
    let container = ModelContainerFactory.makePreview()
    RootView()
        .modelContainer(container)
        .environment(BackendFacade.localOnly(context: container.mainContext))
}
