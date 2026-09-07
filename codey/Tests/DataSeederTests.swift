import SwiftData
import Testing
@testable import codey

struct DataSeederTests {

    @Test @MainActor func seedsTopicsIntoEmptyStore() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext

        DataSeeder.seedIfNeeded(context: context)

        let topics = try context.fetch(FetchDescriptor<Topic>())
        #expect(topics.count == QuestionBankLoader.expectedTopicCount)
        #expect(topics.allSatisfy { !$0.questions.isEmpty })
    }
}
