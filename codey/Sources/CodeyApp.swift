import SwiftData
import SwiftUI

@main
struct CodeyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [UserProfile.self, Topic.self, Question.self])
    }
}
