import Testing
@testable import codey

/// The bundled questions-seed.json decodes, and malformed banks are rejected.
struct QuestionBankLoaderTests {

    @Test func loadsExpectedBankFromBundle() throws {
        let bank = try QuestionBankLoader.loadBank()
        #expect(bank.topics.count == QuestionBankLoader.expectedTopicCount)
        #expect(bank.questions.count == QuestionBankLoader.expectedQuestionCount)
        #expect(Set(bank.topics.map(\.id)).count == bank.topics.count)
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
