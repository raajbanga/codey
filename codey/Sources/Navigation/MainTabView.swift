import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case topics
    case decks
    case analytics
    case settings
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .decks

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DeckLibraryView()
            }
            .tabItem {
                Label("Decks", systemImage: "rectangle.stack.fill")
            }
            .tag(AppTab.decks)

            NavigationStack {
                QuizTopicsView()
            }
            .tabItem {
                Label("Quiz", systemImage: "questionmark.bubble.fill")
            }
            .tag(AppTab.topics)

            NavigationStack {
                AnalyticsDashboardView()
            }
            .tabItem {
                Label("Analytics", systemImage: "chart.bar.xaxis")
            }
            .tag(AppTab.analytics)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(AppTab.settings)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(ModelContainerFactory.makePreview())
}
