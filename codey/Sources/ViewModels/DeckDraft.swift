import Foundation

/// Editable, in-memory copy of a deck while it's in the builder (the
/// Drafting state). Plain values, so edits never touch SwiftData until Save.
struct DeckDraft: Equatable {
    /// nil for a new deck.
    var deckID: UUID?
    var title: String
    var topicId: String
    var cards: [CardDraft]

    static func new(topicId: String) -> DeckDraft {
        DeckDraft(deckID: nil, title: "", topicId: topicId, cards: [CardDraft()])
    }

    init(deckID: UUID?, title: String, topicId: String, cards: [CardDraft]) {
        self.deckID = deckID
        self.title = title
        self.topicId = topicId
        self.cards = cards
    }

    init(deck: FlashcardDeck) {
        self.init(
            deckID: deck.id,
            title: deck.title,
            topicId: deck.topicId,
            cards: deck.activeCards.map(CardDraft.init(card:))
        )
    }
}

struct CardDraft: Identifiable, Equatable {
    let id: UUID
    var prompt: String
    var answer: String
    var snippet: SnippetDraft?
    var difficulty: Difficulty?

    init(id: UUID = UUID(), prompt: String = "", answer: String = "", snippet: SnippetDraft? = nil, difficulty: Difficulty? = nil) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.snippet = snippet
        self.difficulty = difficulty
    }

    init(card: Flashcard) {
        self.init(
            id: card.id,
            prompt: card.prompt,
            answer: card.answer,
            snippet: card.codeSnippet.map { SnippetDraft(language: $0.language, source: $0.source) },
            difficulty: card.difficulty
        )
    }

    var codeSnippet: CodeSnippet? {
        snippet.map { CodeSnippet(language: $0.language, source: $0.source) }
    }

    var validationFields: ModelValidator.CardFields {
        ModelValidator.CardFields(
            id: id,
            prompt: prompt,
            answer: answer,
            codeLanguage: snippet?.language.rawValue,
            codeSource: snippet?.source
        )
    }

    /// First line of the prompt, for thumbnails.
    var summary: String {
        prompt.split(separator: "\n").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
    }
}

struct SnippetDraft: Equatable {
    var language: CodeLanguage = .swift
    var source: String = ""
}
