import Foundation

struct TopicSeed: Decodable, Equatable {
    let id: String
    let title: String
    let summary: String
    let iconName: String
}

/// An unknown difficulty fails decoding, so the bank never loads half-valid.
struct QuestionSeed: Decodable, Equatable {
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
        case .invalidCorrectOptionIndex(let questionId, let index, let optionCount):
            return "Question '\(questionId)' has correctOptionIndex \(index) out of range for \(optionCount) options"
        }
    }
}

enum QuestionBankLoader {
    static let expectedSchemaVersion = 1
    static let expectedTopicCount = 8
    static let expectedQuestionCount = 176

    private static let fileName = "questions-seed"

    /// The bundled bank as plain values, validated. The seeder upserts these.
    static func loadBank(from bundle: Bundle = .main) throws -> QuestionBank {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw QuestionBankLoaderError.fileNotFound
        }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))

        guard file.schemaVersion == expectedSchemaVersion else {
            throw QuestionBankLoaderError.unsupportedSchemaVersion(file.schemaVersion)
        }
        guard !file.topics.isEmpty else {
            throw QuestionBankLoaderError.emptyTopics
        }

        let topicIds = Set(file.topics.map(\.id))
        for question in file.questions {
            guard topicIds.contains(question.topicId) else {
                throw QuestionBankLoaderError.unknownTopicId(questionId: question.id, topicId: question.topicId)
            }
            guard question.options.indices.contains(question.correctOptionIndex) else {
                throw QuestionBankLoaderError.invalidCorrectOptionIndex(
                    questionId: question.id,
                    index: question.correctOptionIndex,
                    optionCount: question.options.count
                )
            }
        }
        return QuestionBank(topics: file.topics, questions: file.questions)
    }

    /// questions-seed.json as decoded.
    private struct File: Decodable {
        let schemaVersion: Int
        let topics: [TopicSeed]
        let questions: [QuestionSeed]
    }
}
