import Foundation
import Testing
@testable import codey

/// FR-09: flashcard.schema.json and ModelValidator must never drift apart.
struct FlashcardSchemaFileTests {

    private func loadSchema() throws -> [String: Any] {
        let url = try #require(Bundle.main.url(forResource: "flashcard.schema", withExtension: "json"))
        return try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func property(_ name: String) throws -> [String: Any] {
        let properties = try #require(try loadSchema()["properties"] as? [String: Any])
        return try #require(properties[name] as? [String: Any])
    }

    @Test func textLimitsMatchValidator() throws {
        let prompt = try property("prompt")
        #expect(prompt["minLength"] as? Int == ModelValidator.Limits.prompt.lowerBound)
        #expect(prompt["maxLength"] as? Int == ModelValidator.Limits.prompt.upperBound)

        let answer = try property("answer")
        #expect(answer["minLength"] as? Int == ModelValidator.Limits.answer.lowerBound)
        #expect(answer["maxLength"] as? Int == ModelValidator.Limits.answer.upperBound)
    }

    @Test func snippetLimitsMatchValidator() throws {
        let source = try property("codeSource")
        #expect(source["minLength"] as? Int == ModelValidator.Limits.snippetSource.lowerBound)
        #expect(source["maxLength"] as? Int == ModelValidator.Limits.snippetSource.upperBound)
        #expect(source["x-maxLines"] as? Int == ModelValidator.Limits.snippetMaxLines)
    }

    @Test func enumsMatchSwiftTypes() throws {
        let languages = try #require(try property("codeLanguage")["enum"] as? [Any])
        #expect(languages.compactMap { $0 as? String } == CodeLanguage.allCases.map(\.rawValue))

        let difficulties = try #require(try property("difficulty")["enum"] as? [Any])
        #expect(difficulties.compactMap { $0 as? String } == Difficulty.allCases.map(\.rawValue))

        let mastery = try property("masteryScore")
        #expect(mastery["maximum"] as? Int == Flashcard.maxMastery)
    }

    @Test func schemaCoversEveryPayloadField() throws {
        let properties = try #require(try loadSchema()["properties"] as? [String: Any])
        let payload = FlashcardPayload(
            id: UUID(), prompt: "p", answer: "a", codeLanguage: "swift", codeSource: "x",
            difficulty: .easy, sortIndex: 0, masteryScore: 0,
            createdAt: .now, updatedAt: .now, deletedAt: .now
        )
        let encoded = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        #expect(Set(encoded.keys) == Set(properties.keys))
    }
}
