import Foundation
import Supabase

/// The content_* tables (supabase/migrations/20261116000000_content.sql),
/// readable by anyone with the anon key, rebuilt into the bundled JSON
/// format so one set of loaders checks both.
extension SupabaseDataClient {
    func fetchContent() async throws -> ContentFiles {
        async let topics: [ContentRow.Topic] = fetchContentTable("content_topics", order: ["sort_index", "id"])
        async let questions: [ContentRow.Question] = fetchContentTable("content_questions", order: ["sort_index", "id"])
        async let exercises: [ContentRow.Exercise] = fetchContentTable("content_exercises", order: ["sort_index", "id"])
        async let decks: [ContentRow.Deck] = fetchContentTable("content_decks", order: ["sort_index", "starter_key"])
        async let cards: [ContentRow.Card] = fetchContentTable("content_cards", order: ["deck_key", "sort_index", "id"])

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let cardsByDeck = Dictionary(grouping: try await cards, by: \.deckKey)
        let deckFile = ContentRow.DeckFile(decks: try await decks.map { deck in
            ContentRow.DeckOut(
                starterKey: deck.starterKey, topicId: deck.topicId, title: deck.title,
                cards: (cardsByDeck[deck.starterKey] ?? []).map(\.out)
            )
        })
        return ContentFiles(
            questions: try encoder.encode(ContentRow.QuestionFile(topics: try await topics, questions: try await questions)),
            decks: try encoder.encode(deckFile),
            exercises: try encoder.encode(ContentRow.ExerciseFile(exercises: try await exercises))
        )
    }

    /// Every row, a page at a time (PostgREST caps a response at max-rows).
    private func fetchContentTable<Row: Decodable & Sendable>(_ table: String, order: [String]) async throws -> [Row] {
        var rows: [Row] = []
        while true {
            var query: PostgrestTransformBuilder = client.from(table).select()
            for column in order { query = query.order(column) }
            let page: [Row] = try await query
                .range(from: rows.count, to: rows.count + pageSize - 1)
                .execute()
                .value
            rows += page
            if page.count < pageSize { return rows }
        }
    }
}

/// Rows as PostgREST sends them (snake_case, decoded by the client's
/// coders) and encoded back in the bundled files' camelCase.
private enum ContentRow {
    struct Topic: Codable, Sendable {
        let id, title, summary, iconName: String
    }

    struct Question: Codable, Sendable {
        let id, topicId, prompt: String
        let options: [String]
        let correctOptionIndex: Int
        let explanation, difficulty: String
    }

    struct Exercise: Codable, Sendable {
        struct Blank: Codable, Sendable { let accepted: [String] }
        let id, topicId, title, language, prompt, code: String
        let blanks: [Blank]
        let explanation: String
    }

    struct Deck: Decodable, Sendable {
        let starterKey, topicId, title: String
    }

    struct Card: Decodable, Sendable {
        let id, deckKey, prompt, answer, difficulty: String
        let codeLanguage, codeSource: String?

        var out: CardOut {
            CardOut(
                id: id, prompt: prompt, answer: answer, difficulty: difficulty,
                code: codeLanguage.flatMap { language in codeSource.map { CardOut.Code(language: language, source: $0) } }
            )
        }
    }

    struct CardOut: Encodable {
        struct Code: Encodable { let language, source: String }
        let id, prompt, answer, difficulty: String
        let code: Code?
    }

    struct DeckOut: Encodable {
        let starterKey, topicId, title: String
        let cards: [CardOut]
    }

    struct QuestionFile: Encodable {
        var schemaVersion = 1
        let topics: [Topic]
        let questions: [Question]
    }

    struct ExerciseFile: Encodable {
        var schemaVersion = 1
        let exercises: [Exercise]
    }

    struct DeckFile: Encodable {
        var schemaVersion = 1
        let decks: [DeckOut]
    }
}
