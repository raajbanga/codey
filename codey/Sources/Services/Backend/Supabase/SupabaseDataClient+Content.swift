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
        async let challenges: [ContentRow.Challenge] = fetchContentTable("content_challenges", order: ["sort_index", "id"])
        async let starters: [ContentRow.Starter] = fetchContentTable("content_challenge_starters", order: ["challenge_id", "language"])
        // RLS returns the example tests only (FR-72).
        async let examples: [ContentRow.Example] = fetchContentTable("content_challenge_tests", order: ["challenge_id", "ordinal"])

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let cardsByDeck = Dictionary(grouping: try await cards, by: \.deckKey)
        let deckFile = ContentRow.DeckFile(decks: try await decks.map { deck in
            ContentRow.DeckOut(
                starterKey: deck.starterKey, topicId: deck.topicId, title: deck.title,
                cards: (cardsByDeck[deck.starterKey] ?? []).map(\.out)
            )
        })
        let startersByChallenge = Dictionary(grouping: try await starters, by: \.challengeId)
        let examplesByChallenge = Dictionary(grouping: try await examples, by: \.challengeId)
        let challengeFile = ChallengeLoader.File(challenges: try await challenges.map { row in
            row.challenge(
                starters: startersByChallenge[row.id] ?? [],
                examples: examplesByChallenge[row.id] ?? []
            )
        })
        return ContentFiles(
            questions: try encoder.encode(ContentRow.QuestionFile(topics: try await topics, questions: try await questions)),
            decks: try encoder.encode(deckFile),
            exercises: try encoder.encode(ContentRow.ExerciseFile(exercises: try await exercises)),
            challenges: try encoder.encode(challengeFile)
        )
    }

    /// run-challenge (S45). The signed-in user's token (or the anon key)
    /// goes with it; the function rate-limits by user, or by IP for guests.
    func runChallenge(_ request: ChallengeRunRequest) async throws -> ChallengeVerdict {
        do {
            return try await client.functions.invoke(
                "run-challenge",
                options: FunctionInvokeOptions(body: request),
                decoder: JSONDecoder()
            )
        } catch FunctionsError.httpError(let code, let data) {
            let message = (try? JSONDecoder().decode(RunFailure.self, from: data))?.message ?? "The code runner returned an error (\(code))."
            switch code {
            case 429: throw ChallengeRunError.rateLimited(message)
            case 503: throw ChallengeRunError.runnerDown(message)
            default: throw ChallengeRunError.other(message)
            }
        } catch let error as URLError {
            throw error.code == .notConnectedToInternet || error.code == .networkConnectionLost
                ? ChallengeRunError.offline
                : ChallengeRunError.runnerDown("Couldn't reach the code runner. Try again.")
        }
    }

    private struct RunFailure: Decodable { let message: String }

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
        let hints: [String]?
    }

    struct Challenge: Decodable, Sendable {
        struct Param: Decodable, Sendable { let name, type: String }
        let id, topicId, title, difficulty, statement: String
        let constraints, hints: [String]
        let functionName: String
        let params: [Param]
        let returnType, comparator, editorial: String

        func challenge(starters: [Starter], examples: [Example]) -> codey.Challenge {
            codey.Challenge(
                id: id, topicId: topicId, title: title,
                difficulty: Difficulty(rawValue: difficulty) ?? .medium,
                statement: statement, constraints: constraints, hints: hints,
                functionName: functionName,
                params: params.map { .init(name: $0.name, type: $0.type) },
                returnType: returnType, comparator: comparator, editorial: editorial,
                starters: Dictionary(starters.map { ($0.language, $0.code) }, uniquingKeysWith: { first, _ in first }),
                examples: examples.map { example in
                    .init(
                        input: zip(params, example.args).map { "\($0.name) = \($1)" }.joined(separator: ", "),
                        output: example.expected.description,
                        explanation: example.explanation
                    )
                }
            )
        }
    }

    struct Starter: Decodable, Sendable {
        let challengeId, language, code: String
    }

    struct Example: Decodable, Sendable {
        let challengeId: String
        let args: [JSONValue]
        let expected: JSONValue
        let explanation: String?
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
