import SwiftData
import SwiftUI

enum PreviewContainer {
    @MainActor
    static func make(inMemory: Bool = true) -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let container = try! ModelContainer(
            for: UserProfile.self, Topic.self, Question.self,
            configurations: config
        )
        DataSeeder.seedIfNeeded(context: container.mainContext)
        return container
    }
}
