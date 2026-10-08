import Foundation
import Testing
@testable import codey

struct FlashcardFactoryTests {
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)
    private var factory: FlashcardFactory { FlashcardFactory(now: { fixedNow }) }

    private func errors(_ body: () throws -> Flashcard) -> [FieldError] {
        do {
            _ = try body()
            return []
        } catch FactoryError.invalid(let errors) {
            return errors
        } catch {
            Issue.record("Unexpected error \(error)")
            return []
        }
    }

    @Test func createsValidCardWithDefaults() throws {
        let id = UUID()
        let card = try factory.createCard(
            id: id,
            prompt: "  What does `defer` do?\r\n",
            answer: "Runs at scope exit.",
            code: CodeSnippet(language: .swift, source: "defer { close() }"),
            difficulty: .medium,
            sortIndex: 3
        )
        #expect(card.id == id)
        #expect(card.prompt == "What does `defer` do?")
        #expect(card.answer == "Runs at scope exit.")
        #expect(card.codeSnippet == CodeSnippet(language: .swift, source: "defer { close() }"))
        #expect(card.difficulty == .medium)
        #expect(card.sortIndex == 3)
        #expect(card.masteryScore == 0)
        #expect(card.createdAt == fixedNow)
        #expect(card.updatedAt == fixedNow)
        #expect(card.deletedAt == nil && card.retiredAt == nil && card.lastReviewedAt == nil)
    }

    @Test func invalidInputThrowsFieldErrorsKeyedByCardId() {
        let id = UUID()
        let result = errors { try factory.createCard(id: id, prompt: "   ", answer: String(repeating: "a", count: 501)) }
        #expect(result.map(\.field) == [.cardPrompt(id), .cardAnswer(id)])
    }

    @Test func snippetIsNormalized() throws {
        let messy = "\r\n\n\tdef f():  \r\n\t\treturn 1\t\n\n  \n"
        let card = try factory.createCard(prompt: "p", answer: "a", code: CodeSnippet(language: .python, source: messy))
        #expect(card.codeSnippet?.source == "    def f():\n        return 1")
    }

    @Test func normalizationKeepsLeadingIndentAndInnerBlankLines() {
        #expect(FlashcardFactory.normalizeSnippetSource("  a\n\n  b") == "  a\n\n  b")
        #expect(FlashcardFactory.normalizeText("a\rb\r\nc") == "a\nb\nc")
    }

    @Test func whitespaceOnlySnippetIsRejectedAfterNormalizing() {
        let id = UUID()
        let result = errors { try factory.createCard(id: id, prompt: "p", answer: "a", code: CodeSnippet(language: .java, source: "\t\n  \n")) }
        #expect(result == [FieldError(field: .snippetSource(id), reason: .empty)])
    }

    @Test func payloadRoundTripIsIdentity() throws {
        let original = try factory.createCard(
            prompt: "p", answer: "a",
            code: CodeSnippet(language: .cpp, source: "int main() {\n    return 0;\n}"),
            difficulty: .hard, sortIndex: 7
        )
        original.updateMastery(rating: .easy)
        let payload = original.toPayload()

        let rebuilt = try FlashcardFactory().createCard(from: payload)

        #expect(rebuilt.toPayload() == payload)
        #expect(payload.masteryScore == 2)
        #expect(payload.codeLanguage == "cpp")
    }

    @Test func payloadRoundTripSurvivesJSON() throws {
        let card = try factory.createCard(prompt: "p", answer: "a", code: CodeSnippet(language: .swift, source: "x"), difficulty: .easy)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FlashcardPayload.self, from: encoder.encode(card.toPayload()))
        #expect(try FlashcardFactory().createCard(from: decoded).toPayload() == card.toPayload())
    }

    @Test func payloadDefaultsFillMissingFields() throws {
        let card = try factory.createCard(from: FlashcardPayload(prompt: "p", answer: "a", masteryScore: 99))
        #expect(card.masteryScore == 5)
        #expect(card.createdAt == fixedNow && card.updatedAt == fixedNow)

        let earlier = Date(timeIntervalSince1970: 1_000)
        let kept = try factory.createCard(from: FlashcardPayload(prompt: "p", answer: "a", masteryScore: -3, createdAt: earlier))
        #expect(kept.masteryScore == 0)
        #expect(kept.createdAt == earlier && kept.updatedAt == earlier)
    }

    @Test func payloadWithBadLanguageIsRejected() {
        let id = UUID()
        let result = errors {
            try factory.createCard(from: FlashcardPayload(id: id, prompt: "p", answer: "a", codeLanguage: "ruby", codeSource: "puts 1"))
        }
        #expect(result.map(\.field) == [.snippetLanguage(id)])
    }

    @Test func payloadWithSourceButNoLanguageIsRejected() {
        let id = UUID()
        let result = errors {
            try factory.createCard(from: FlashcardPayload(id: id, prompt: "p", answer: "a", codeSource: "puts 1"))
        }
        #expect(result == [FieldError(field: .snippetLanguage(id), reason: .missingLanguage)])
    }
}
