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

struct TopicSeed: Equatable {
    let id: String
    let title: String
    let summary: String
    let iconName: String
}

struct QuestionSeed: Equatable {
    let id: String
    let topicId: String
    let prompt: String
    let options: [String]
    let correctOptionIndex: Int
    let explanation: String
    let difficulty: Difficulty
}

/// Bundled quiz content, as plain values (not yet in SwiftData).
struct QuestionBank: Equatable {
    var topics: [TopicSeed]
    var questions: [QuestionSeed]
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
    static let expectedQuestionCount = 88

    private static let fileName = "questions-seed"
    private final class BundleToken {}

    static var resourceBundle: Bundle {
        if Bundle.main.url(forResource: fileName, withExtension: "json") != nil {
            return .main
        }
        return Bundle(for: BundleToken.self)
    }

    /// The bundled bank as plain values, validated. The seeder upserts these.
    static func loadBank(from bundle: Bundle = resourceBundle) throws -> QuestionBank {
        let file = try decode(from: bundle)
        return QuestionBank(
            topics: file.topics.map {
                TopicSeed(id: $0.id, title: $0.title, summary: $0.summary, iconName: $0.iconName)
            },
            questions: file.questions.compactMap { dto in
                // decode(from:) already rejected unknown difficulties.
                guard let difficulty = Difficulty(rawValue: dto.difficulty) else { return nil }
                return QuestionSeed(
                    id: dto.id,
                    topicId: dto.topicId,
                    prompt: dto.prompt,
                    options: dto.options,
                    correctOptionIndex: dto.correctOptionIndex,
                    explanation: dto.explanation,
                    difficulty: difficulty
                )
            }
        )
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
