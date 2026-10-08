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

    /// B12 / Stage 6.5: enough per tier that retirement and the 70/30 mix work.
    @Test func everyTopicHasEnoughQuestionsPerTier() throws {
        let bank = try QuestionBankLoader.loadBank()
        for topic in bank.topics {
            let questions = bank.questions.filter { $0.topicId == topic.id }
            #expect(questions.filter { $0.difficulty == .easy }.count >= 8, "\(topic.id) Easy")
            #expect(questions.filter { $0.difficulty == .medium }.count >= 8, "\(topic.id) Medium")
            #expect(questions.filter { $0.difficulty == .hard }.count >= 6, "\(topic.id) Hard")
        }
    }

    @Test func questionIDsAreUniqueAndOptionsAreFourDistinctChoices() throws {
        let bank = try QuestionBankLoader.loadBank()
        #expect(Set(bank.questions.map(\.id)).count == bank.questions.count)
        for question in bank.questions {
            #expect(question.options.count == 4, "\(question.id)")
            #expect(Set(question.options).count == 4, "\(question.id) has duplicate options")
        }
    }
}
