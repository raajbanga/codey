import Foundation

private struct TopicDTO: Codable {
    let id: String
    let title: String
    let summary: String
    let iconName: String
}

private struct QuestionDTO: Codable {
    let id: String
    let topicId: String
    let prompt: String
    let options: [String]
    let correctOptionIndex: Int
    let explanation: String
    let difficulty: String
}

private struct QuestionBankFile: Codable {
    let schemaVersion: Int
    let topics: [TopicDTO]
    let questions: [QuestionDTO]
}

enum QuestionBankLoaderError: Error, CustomStringConvertible {
    case fileNotFound
    case unsupportedSchemaVersion(Int)
    case emptyTopics
    case unknownTopicId(questionId: String, topicId: String)
    case invalidDifficulty(questionId: String, value: String)
    case invalidCorrectOptionIndex(questionId: String, index: Int, optionCount: Int)

    var description: String {
        switch self {
        case .fileNotFound:
            return "questions-seed.json not found in bundle"
        case .unsupportedSchemaVersion(let version):
            return "Unsupported schema version: \(version)"
        case .emptyTopics:
            return "Question bank contains no topics"
        case .unknownTopicId(let questionId, let topicId):
            return "Question '\(questionId)' references unknown topicId '\(topicId)'"
        case .invalidDifficulty(let questionId, let value):
            return "Question '\(questionId)' has invalid difficulty '\(value)'"
        case .invalidCorrectOptionIndex(let questionId, let index, let optionCount):
            return "Question '\(questionId)' has correctOptionIndex \(index) out of range for \(optionCount) options"
        }
    }
}

enum QuestionBankLoader {
    static let expectedSchemaVersion = 1
    static let expectedTopicCount = 4
    static let expectedQuestionCount = 48

    private static let fileName = "questions-seed"
    private final class BundleToken {}

    static var resourceBundle: Bundle {
        if Bundle.main.url(forResource: fileName, withExtension: "json") != nil {
            return .main
        }
        return Bundle(for: BundleToken.self)
    }

    static func loadTopics(from bundle: Bundle = resourceBundle) throws -> [Topic] {
        let bank = try decode(from: bundle)
        var lookup: [String: Topic] = [:]

        let topics = bank.topics.map { dto -> Topic in
            let topic = Topic(
                id: dto.id,
                title: dto.title,
                summary: dto.summary,
                iconName: dto.iconName
            )
            lookup[dto.id] = topic
            return topic
        }

        for dto in bank.questions {
            guard let topic = lookup[dto.topicId],
                  let difficulty = Difficulty(rawValue: dto.difficulty) else {
                continue
            }
            topic.questions.append(
                Question(
                    id: dto.id,
                    prompt: dto.prompt,
                    options: dto.options,
                    correctOptionIndex: dto.correctOptionIndex,
                    explanation: dto.explanation,
                    difficulty: difficulty,
                    topic: topic
                )
            )
        }

        return topics
    }

    private static func decode(from bundle: Bundle) throws -> QuestionBankFile {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw QuestionBankLoaderError.fileNotFound
        }

        let bank = try JSONDecoder().decode(QuestionBankFile.self, from: Data(contentsOf: url))

        guard bank.schemaVersion == expectedSchemaVersion else {
            throw QuestionBankLoaderError.unsupportedSchemaVersion(bank.schemaVersion)
        }
        guard !bank.topics.isEmpty else {
            throw QuestionBankLoaderError.emptyTopics
        }

        let topicIds = Set(bank.topics.map(\.id))
        for question in bank.questions {
            guard topicIds.contains(question.topicId) else {
                throw QuestionBankLoaderError.unknownTopicId(
                    questionId: question.id,
                    topicId: question.topicId
                )
            }
            guard Difficulty(rawValue: question.difficulty) != nil else {
                throw QuestionBankLoaderError.invalidDifficulty(
                    questionId: question.id,
                    value: question.difficulty
                )
            }
            guard question.correctOptionIndex >= 0,
                  question.correctOptionIndex < question.options.count else {
                throw QuestionBankLoaderError.invalidCorrectOptionIndex(
                    questionId: question.id,
                    index: question.correctOptionIndex,
                    optionCount: question.options.count
                )
            }
        }

        return bank
    }
}
