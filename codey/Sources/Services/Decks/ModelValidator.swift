import Foundation

/// Which input a validation error belongs to, so the UI can show it inline
/// next to that field (FR-10).
enum ValidationField: Hashable {
    case deckTitle
    case deckTopic
    case cardPrompt(UUID)
    case cardAnswer(UUID)
    case snippetSource(UUID)
    case snippetLanguage(UUID)
    case deckHasNoCards
    /// FR-04 profile name.
    case displayName
    /// FR-49 UI/UX issue report.
    case feedback
}

struct FieldError: Hashable, Error {
    enum Reason: Hashable {
        case empty
        case tooLong(max: Int, actual: Int)
        case tooManyLines(max: Int, actual: Int)
        case unknownTopic
        case missingLanguage
        case unsupportedLanguage(String)
        case noCards
    }

    let field: ValidationField
    let reason: Reason

    var message: String {
        switch reason {
        case .empty:
            "Can't be empty."
        case .tooLong(let max, let actual):
            "Too long (\(actual)/\(max) characters)."
        case .tooManyLines(let max, let actual):
            "Too many lines (\(actual)/\(max))."
        case .unknownTopic:
            "Choose a topic."
        case .missingLanguage:
            "Choose a language for this code."
        case .unsupportedLanguage(let value):
            "\"\(value)\" isn't a supported language."
        case .noCards:
            "Add at least one card."
        }
    }
}

typealias ValidationResult = [FieldError]

/// Content rules for decks and cards (FR-09, FR-10). The limits are mirrored
/// in Resources/Schemas/flashcard.schema.json (a test keeps them equal) and,
/// from Stage 8, in the SQL CHECK constraints.
///
/// Lengths are counted in Unicode scalars after trimming whitespace, to match
/// Postgres char_length() and JSON Schema maxLength. Markdown syntax counts.
/// Code fences inside prompt/answer are allowed (D2 r2).
struct ModelValidator {
    enum Limits {
        static let deckTitle = 1...60
        static let prompt = 1...500
        static let answer = 1...500
        static let snippetSource = 1...2000
        static let snippetMaxLines = 80
        /// FR-04; matches profiles.display_name.
        static let displayName = 1...30
        /// FR-49; matches feedback_reports.description.
        static let feedback = 1...1000
    }

    /// Raw card input, before the factory turns it into a Flashcard.
    struct CardFields {
        var id: UUID
        var prompt: String
        var answer: String
        /// Raw language key (CodeLanguage.rawValue), nil when there's no code.
        var codeLanguage: String?
        var codeSource: String?
    }

    func validateCard(_ card: CardFields) -> ValidationResult {
        var errors: ValidationResult = []
        errors += Self.checkLength(card.prompt, Limits.prompt, field: .cardPrompt(card.id))
        errors += Self.checkLength(card.answer, Limits.answer, field: .cardAnswer(card.id))

        guard card.codeLanguage != nil || card.codeSource != nil else { return errors }

        if let language = card.codeLanguage {
            if CodeLanguage(rawValue: language) == nil {
                errors.append(FieldError(field: .snippetLanguage(card.id), reason: .unsupportedLanguage(language)))
            }
        } else {
            errors.append(FieldError(field: .snippetLanguage(card.id), reason: .missingLanguage))
        }

        let source = card.codeSource ?? ""
        let sourceErrors = Self.checkLength(source, Limits.snippetSource, field: .snippetSource(card.id))
        errors += sourceErrors
        if sourceErrors.isEmpty {
            let lines = Self.lineCount(source)
            if lines > Limits.snippetMaxLines {
                errors.append(FieldError(
                    field: .snippetSource(card.id),
                    reason: .tooManyLines(max: Limits.snippetMaxLines, actual: lines)
                ))
            }
        }
        return errors
    }

    /// A deck needs a valid title, a known topic, and at least one valid card
    /// (UC-01).
    func validateDeck(
        title: String,
        topicId: String,
        cards: [CardFields],
        knownTopicIds: Set<String>
    ) -> ValidationResult {
        var errors = Self.checkLength(title, Limits.deckTitle, field: .deckTitle)
        if !knownTopicIds.contains(topicId) {
            errors.append(FieldError(field: .deckTopic, reason: .unknownTopic))
        }
        if cards.isEmpty {
            errors.append(FieldError(field: .deckHasNoCards, reason: .noCards))
        }
        for card in cards {
            errors += validateCard(card)
        }
        return errors
    }

    /// FR-04: the display name is checked like deck text (trimmed scalars).
    func validateDisplayName(_ name: String) -> ValidationResult {
        Self.checkLength(name, Limits.displayName, field: .displayName)
    }

    /// FR-49: an issue report's description.
    func validateFeedback(_ text: String) -> ValidationResult {
        Self.checkLength(text, Limits.feedback, field: .feedback)
    }

    /// Length as the limits count it: Unicode scalars after trimming.
    static func measuredLength(_ text: String) -> Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count
    }

    static func lineCount(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else { return 0 }
        return trimmed.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    /// For the builder's soft hint ("use Add code"); fences are never an error.
    static func containsCodeFence(_ text: String) -> Bool {
        text.contains("```") || text.contains("~~~")
    }

    private static func checkLength(
        _ text: String,
        _ limit: ClosedRange<Int>,
        field: ValidationField
    ) -> ValidationResult {
        let length = measuredLength(text)
        if length < limit.lowerBound {
            return [FieldError(field: field, reason: .empty)]
        }
        if length > limit.upperBound {
            return [FieldError(field: field, reason: .tooLong(max: limit.upperBound, actual: length))]
        }
        return []
    }
}

/// So `$actionError.attempt` alerts show "Too long (31/30 characters)."
/// instead of a generic error.
extension FieldError: LocalizedError {
    var errorDescription: String? { message }
}
