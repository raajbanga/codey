import Foundation
import Testing
@testable import codey

/// ModelValidator limits (FR-09/10, FR-04, FR-49, FR-50/51), each tested at ±1.
struct ModelValidatorTests {
    private let id = UUID()
    private let topics: Set<String> = ["topic-data-structures"]

    private func card(
        prompt: String = "Prompt",
        answer: String = "Answer",
        language: String? = nil,
        source: String? = nil
    ) -> ModelValidator.CardFields {
        .init(id: id, prompt: prompt, answer: answer, codeLanguage: language, codeSource: source)
    }

    private func fields(_ result: ValidationResult) -> [ValidationField] { result.map(\.field) }

    @Test func validCardHasNoErrors() {
        #expect(ModelValidator.validateCard(card()).isEmpty)
        #expect(ModelValidator.validateCard(card(language: "swift", source: "let x = 1")).isEmpty)
    }

    @Test(arguments: [(1, true), (500, true), (501, false)])
    func promptLimit(length: Int, valid: Bool) {
        let result = ModelValidator.validateCard(card(prompt: String(repeating: "a", count: length)))
        #expect(result.isEmpty == valid)
        if !valid { #expect(result == [FieldError(field: .cardPrompt(id), reason: .tooLong(max: 500, actual: length))]) }
    }

    @Test(arguments: [(1, true), (500, true), (501, false)])
    func answerLimit(length: Int, valid: Bool) {
        let result = ModelValidator.validateCard(card(answer: String(repeating: "a", count: length)))
        #expect(result.isEmpty == valid)
        if !valid { #expect(fields(result) == [.cardAnswer(id)]) }
    }

    @Test(arguments: ["", "   ", "\n\t \n"])
    func blankPromptAndAnswerAreRejected(text: String) {
        let result = ModelValidator.validateCard(card(prompt: text, answer: text))
        #expect(result == [
            FieldError(field: .cardPrompt(id), reason: .empty),
            FieldError(field: .cardAnswer(id), reason: .empty),
        ])
    }

    @Test func surroundingWhitespaceDoesNotCount() {
        let text = "  " + String(repeating: "a", count: 500) + "\n\n"
        #expect(ModelValidator.validateCard(card(prompt: text)).isEmpty)
    }

    @Test func lengthCountsUnicodeScalarsLikePostgres() {
        // "👍🏽" is one Character but two scalars; char_length() counts two.
        #expect(ModelValidator.measuredLength("👍🏽") == 2)
        #expect(ModelValidator.measuredLength(String(repeating: "é", count: 500)) == 500)
    }

    @Test func fencedTextIsAllowedAndCounted() {
        let fence = "```swift\nlet x = 1\n```"
        let atLimit = fence + String(repeating: "a", count: 500 - fence.unicodeScalars.count)
        #expect(ModelValidator.validateCard(card(prompt: atLimit)).isEmpty)
        #expect(ModelValidator.containsCodeFence(atLimit))
        #expect(fields(ModelValidator.validateCard(card(prompt: atLimit + "a"))) == [.cardPrompt(id)])
    }

    @Test(arguments: [(1, true), (2000, true), (2001, false)])
    func snippetCharacterLimit(length: Int, valid: Bool) {
        let source = String(repeating: "x", count: length)
        let result = ModelValidator.validateCard(card(language: "python", source: source))
        #expect(result.isEmpty == valid)
        if !valid { #expect(fields(result) == [.snippetSource(id)]) }
    }

    @Test(arguments: [(80, true), (81, false)])
    func snippetLineLimit(lines: Int, valid: Bool) {
        let source = Array(repeating: "x", count: lines).joined(separator: "\n")
        let result = ModelValidator.validateCard(card(language: "java", source: source))
        #expect(result.isEmpty == valid)
        if !valid { #expect(result == [FieldError(field: .snippetSource(id), reason: .tooManyLines(max: 80, actual: 81))]) }
    }

    @Test func blankSnippetIsRejected() {
        #expect(ModelValidator.validateCard(card(language: "swift", source: " \n ")) == [FieldError(field: .snippetSource(id), reason: .empty)])
        #expect(ModelValidator.validateCard(card(language: "swift", source: nil)) == [FieldError(field: .snippetSource(id), reason: .empty)])
    }

    @Test func snippetLanguageMustBeKnownAndPresent() {
        #expect(ModelValidator.validateCard(card(language: "rust", source: "fn main() {}"))
            == [FieldError(field: .snippetLanguage(id), reason: .unsupportedLanguage("rust"))])
        #expect(ModelValidator.validateCard(card(language: "c++", source: "int x;")).map(\.field) == [.snippetLanguage(id)])
        #expect(ModelValidator.validateCard(card(language: nil, source: "print(1)"))
            == [FieldError(field: .snippetLanguage(id), reason: .missingLanguage)])
    }

    @Test(arguments: [(1, true), (60, true), (61, false), (0, false)])
    func deckTitleLimit(length: Int, valid: Bool) {
        let result = ModelValidator.validateDeck(
            title: String(repeating: "t", count: length),
            topicId: "topic-data-structures",
            cards: [card()],
            knownTopicIds: topics
        )
        #expect(result.isEmpty == valid)
        if !valid { #expect(fields(result) == [.deckTitle]) }
    }

    @Test func deckNeedsKnownTopicAndACard() {
        let result = ModelValidator.validateDeck(title: "Deck", topicId: "topic-nope", cards: [], knownTopicIds: topics)
        #expect(fields(result) == [.deckTopic, .deckHasNoCards])
    }

    @Test func deckErrorsAreKeyedPerCard() {
        let good = card()
        let bad = ModelValidator.CardFields(id: UUID(), prompt: "", answer: "ok", codeLanguage: nil, codeSource: nil)
        let result = ModelValidator.validateDeck(title: "Deck", topicId: "topic-data-structures", cards: [good, bad], knownTopicIds: topics)
        #expect(fields(result) == [.cardPrompt(bad.id)])
        #expect(!result[0].message.isEmpty)
    }
}
