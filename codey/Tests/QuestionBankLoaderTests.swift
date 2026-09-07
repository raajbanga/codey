import Testing
@testable import codey

struct QuestionBankLoaderTests {

    @Test func loadsExpectedBankFromBundle() throws {
        let topics = try QuestionBankLoader.loadTopics()
        #expect(topics.count == QuestionBankLoader.expectedTopicCount)
        #expect(topics.reduce(0) { $0 + $1.questions.count } == QuestionBankLoader.expectedQuestionCount)
    }

    @Test func everyQuestionHasValidTopic() throws {
        let topics = try QuestionBankLoader.loadTopics()
        for topic in topics {
            #expect(!topic.id.isEmpty)
            #expect(!topic.questions.isEmpty)
            for question in topic.questions {
                #expect(question.topic?.id == topic.id)
                #expect(question.options.count == 4)
            }
        }
    }
}
