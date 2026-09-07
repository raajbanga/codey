import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case practice
    case topics
    case analytics
    case settings
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .practice

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PracticeHomeView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Practice", systemImage: "square.stack.fill")
            }
            .tag(AppTab.practice)

            NavigationStack {
                TopicListView()
            }
            .tabItem {
                Label("Topics", systemImage: "folder.fill")
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
