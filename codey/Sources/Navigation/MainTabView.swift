import SwiftData
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                PracticeHomeView()
            }
            .tabItem {
                Label("Practice", systemImage: "square.stack.fill")
            }

            NavigationStack {
                TopicListView()
            }
            .tabItem {
                Label("Topics", systemImage: "folder.fill")
            }

            NavigationStack {
                AnalyticsDashboardView()
            }
            .tabItem {
                Label("Analytics", systemImage: "chart.bar.xaxis")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(PreviewContainer.make())
}
