import Foundation

/// One chat turn as the API sees it (OpenAI-compatible chat format).
struct ChatTurn: Codable, Equatable, Sendable {
    enum Role: String, Codable, Sendable {
        case system, user, assistant
    }

    let role: Role
    let content: String
}

/// What can go wrong asking the model, each with the line the chat shows.
enum AskAIError: Error, Equatable, Sendable {
    case offline
    case timeout
    case unauthorized
    case rateLimited
    case modelUnavailable
    case server
    case emptyReply

    var message: String {
        switch self {
        case .offline: "You're offline. Connect to the internet and try again."
        case .timeout: "The tutor took too long to answer. Try again."
        case .unauthorized: "Ask AI isn't set up correctly (the API key was rejected)."
        case .rateLimited: "The free tutor is busy right now. Wait a moment and try again."
        case .modelUnavailable: "The tutor model is unavailable right now. Try again later."
        case .server: "Something went wrong on the tutor's side. Try again."
        case .emptyReply: "The tutor sent an empty reply. Try again."
        }
    }
}

/// Sends a chat and returns the model's reply text. A protocol so the
/// session can run against a stub in tests and UI tests.
protocol AskAIClient: Sendable {
    func complete(_ turns: [ChatTurn]) async throws(AskAIError) -> String
}

/// Ask AI's only network call (S39): one non-streaming
/// `POST https://openrouter.ai/api/v1/chat/completions` per reply.
/// The key ships in the app (accepted risk, created with a $0 credit limit
/// so it can only use free models); a server-side proxy is Future Work.
struct OpenRouterClient: AskAIClient {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    /// Free models answer in 3–30 s; past this the chat shows Retry.
    static let timeout: TimeInterval = 45

    let apiKey: String
    let model: String
    private let session: URLSession

    /// For the NFR-06 test.
    var minimumTLSVersion: tls_protocol_version_t { session.configuration.tlsMinimumSupportedProtocolVersion }

    init(apiKey: String, model: String, configuration: URLSessionConfiguration = .ephemeral) {
        self.apiKey = apiKey
        self.model = model
        configuration.timeoutIntervalForRequest = Self.timeout
        // NFR-06: the same TLS 1.3 floor as the Supabase session.
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv13
        session = URLSession(configuration: configuration)
    }

    private struct Body: Encodable {
        let model: String
        let messages: [ChatTurn]
        let temperature: Double
        let maxTokens: Int

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature
            case maxTokens = "max_tokens"
        }
    }

    func makeRequest(_ turns: [ChatTurn]) -> URLRequest {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Codey", forHTTPHeaderField: "X-Title")
        // Low temperature: steadier about the rules. The cap keeps replies short.
        request.httpBody = try? JSONEncoder().encode(Body(model: model, messages: turns, temperature: 0.3, maxTokens: 700))
        return request
    }

    func complete(_ turns: [ChatTurn]) async throws(AskAIError) -> String {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: makeRequest(turns))
        } catch {
            throw Self.map(error)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try Self.reply(status: status, data: data)
    }

    // MARK: Response handling (static so tests can call it directly)

    private struct Envelope: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message?
        }

        struct APIError: Decodable {
            let code: Int?
            let message: String?
        }

        let choices: [Choice]?
        let error: APIError?
    }

    /// Reply text from a response, or the error it stands for. OpenRouter
    /// can also return 200 with an `error` object (an upstream failure).
    static func reply(status: Int, data: Data) throws(AskAIError) -> String {
        let envelope = try? JSONDecoder().decode(Envelope.self, from: data)
        let code = envelope?.error?.code ?? status
        if envelope?.error != nil || !(200..<300).contains(status) {
            throw map(status: code, message: envelope?.error?.message ?? "")
        }
        let text = stripReasoning(envelope?.choices?.first?.message?.content ?? "")
        guard !text.isEmpty else { throw .emptyReply }
        return text
    }

    static func map(status: Int, message: String = "") -> AskAIError {
        switch status {
        case 401, 403: .unauthorized
        case 429: .rateLimited
        // 404: model ID gone from the free list; 402: a paid model on a $0 key;
        // 400 naming the model: the ID is invalid.
        case 402, 404: .modelUnavailable
        case 400 where message.localizedCaseInsensitiveContains("model"): .modelUnavailable
        case 408, 504: .timeout
        default: .server
        }
    }

    static func map(_ error: any Error) -> AskAIError {
        switch (error as? URLError)?.code {
        case .timedOut: .timeout
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .cannotFindHost, .cannotConnectToHost,
             .internationalRoamingOff:
            .offline
        default: .server
        }
    }

    /// Some free models inline their chain of thought in `<think>` tags.
    static func stripReasoning(_ text: String) -> String {
        text.replacingOccurrences(of: #"(?s)<think>.*?</think>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
