import Testing
@testable import codey

struct QuestionBankLoaderTests {

    @Test func loadsExpectedBankFromBundle() throws {
        let bank = try QuestionBankLoader.loadBank()
        #expect(bank.topics.count == QuestionBankLoader.expectedTopicCount)
        #expect(bank.questions.count == QuestionBankLoader.expectedQuestionCount)
    }

    @Test func everyQuestionHasValidTopicAndFourOptions() throws {
        let bank = try QuestionBankLoader.loadBank()
        let topicIds = Set(bank.topics.map(\.id))
        #expect(bank.topics.allSatisfy { !$0.id.isEmpty })
        for topic in bank.topics {
            #expect(bank.questions.contains { $0.topicId == topic.id })
        }
        for question in bank.questions {
            #expect(topicIds.contains(question.topicId))
            #expect(question.options.count == 4)
        }
    }

    @Test func idsAreUnique() throws {
        let bank = try QuestionBankLoader.loadBank()
        #expect(Set(bank.topics.map(\.id)).count == bank.topics.count)
        #expect(Set(bank.questions.map(\.id)).count == bank.questions.count)
    }
}
