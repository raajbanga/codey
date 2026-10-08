import Foundation

enum FactoryError: Error, Equatable {
    case invalid([FieldError])
}

/// The only way to make a Flashcard (Factory pattern, §9.2): builder input,
/// starter decks, and synced cards all come through here, so every card is
/// normalized and validated the same way.
struct FlashcardFactory {
    /// Proof of coming from the factory. Its init is fileprivate, so only this
    /// file can build one, and Flashcard's init requires it.
    struct Token {
        fileprivate init() {}
    }

    private let validator = ModelValidator()
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func createCard(
        id: UUID = UUID(),
        prompt: String,
        answer: String,
        code: CodeSnippet? = nil,
        difficulty: Difficulty? = nil,
        sortIndex: Int = 0
    ) throws -> Flashcard {
        try createCard(from: FlashcardPayload(
            id: id,
            prompt: prompt,
            answer: answer,
            codeLanguage: code?.language.rawValue,
            codeSource: code?.source,
            difficulty: difficulty,
            sortIndex: sortIndex
        ))
    }

    /// Builds a card from bundle or sync data. Missing ids and timestamps get
    /// defaults; a given id, mastery, and timestamps are kept.
    func createCard(from payload: FlashcardPayload) throws -> Flashcard {
        let input = applyDefaults(payload)

        let errors = validator.validateCard(ModelValidator.CardFields(
            id: input.id ?? UUID(),
            prompt: input.prompt,
            answer: input.answer,
            codeLanguage: input.codeLanguage,
            codeSource: input.codeSource
        ))
        guard errors.isEmpty else { throw FactoryError.invalid(errors) }

        var snippet: CodeSnippet?
        if let raw = input.codeLanguage, let language = CodeLanguage(rawValue: raw), let source = input.codeSource {
            snippet = CodeSnippet(language: language, source: source)
        }

        return Flashcard(
            Token(),
            id: input.id ?? UUID(),
            prompt: input.prompt,
            answer: input.answer,
            codeSnippet: snippet,
            difficulty: input.difficulty,
            sortIndex: input.sortIndex,
            masteryScore: input.masteryScore ?? 0,
            createdAt: input.createdAt ?? now(),
            updatedAt: input.updatedAt ?? now(),
            deletedAt: input.deletedAt
        )
    }

    /// Edits an existing card through the same normalize + validate path as
    /// creation, so edited content obeys the same rules. Bumps updatedAt only
    /// if something actually changed. Returns whether it did.
    @discardableResult
    func updateCard(
        _ card: Flashcard,
        prompt: String,
        answer: String,
        code: CodeSnippet?,
        difficulty: Difficulty?,
        sortIndex: Int
    ) throws -> Bool {
        let prompt = Self.normalizeText(prompt)
        let answer = Self.normalizeText(answer)
        let code = code.map { CodeSnippet(language: $0.language, source: Self.normalizeSnippetSource($0.source)) }

        let errors = validator.validateCard(ModelValidator.CardFields(
            id: card.id,
            prompt: prompt,
            answer: answer,
            codeLanguage: code?.language.rawValue,
            codeSource: code?.source
        ))
        guard errors.isEmpty else { throw FactoryError.invalid(errors) }

        let changed = card.prompt != prompt || card.answer != answer || card.codeSnippet != code
            || card.difficulty != difficulty || card.sortIndex != sortIndex
        guard changed else { return false }
        card.prompt = prompt
        card.answer = answer
        card.codeSnippet = code
        card.difficulty = difficulty
        card.sortIndex = sortIndex
        card.updatedAt = now()
        return true
    }

    private func applyDefaults(_ payload: FlashcardPayload) -> FlashcardPayload {
        var result = payload
        let timestamp = now()
        result.id = payload.id ?? UUID()
        result.prompt = Self.normalizeText(payload.prompt)
        result.answer = Self.normalizeText(payload.answer)
        result.codeSource = payload.codeSource.map(Self.normalizeSnippetSource)
        result.masteryScore = min(max(payload.masteryScore ?? 0, 0), Flashcard.maxMastery)
        result.createdAt = payload.createdAt ?? timestamp
        result.updatedAt = payload.updatedAt ?? result.createdAt
        return result
    }

    /// Unifies line endings to LF and trims surrounding whitespace.
    static func normalizeText(_ text: String) -> String {
        normalizeLineEndings(text).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// LF line endings, tabs → 4 spaces, no trailing whitespace on any line,
    /// no leading/trailing blank lines. Leading indentation is kept.
    static func normalizeSnippetSource(_ source: String) -> String {
        var lines = normalizeLineEndings(source)
            .replacingOccurrences(of: "\t", with: "    ")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                String(line.reversed().drop(while: { $0 == " " }).reversed())
            }
        while lines.first?.isEmpty == true { lines.removeFirst() }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    private static func normalizeLineEndings(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }
}
