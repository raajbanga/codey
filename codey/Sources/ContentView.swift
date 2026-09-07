import SwiftData
import SwiftUI

public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    public init() {}

    public var body: some View {
        MainTabView()
            .task {
                DataSeeder.seedIfNeeded(context: modelContext)
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer.make())
}
