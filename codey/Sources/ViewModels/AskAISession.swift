import Foundation
import Observation

/// One Ask AI chat (S39, FR-67/68): messages in memory for the question or
/// exercise on screen. A new question or exercise gets a new session;
/// leaving the quiz or exercise drops it. Never persisted, never synced.
@MainActor
@Observable
final class AskAISession: Identifiable {
    struct Message: Identifiable, Equatable {
        enum Role: Equatable { case student, tutor }

        let id = UUID()
        let role: Role
        let text: String
    }

    let context: AskAIContext
    nonisolated var id: String { context.id }
    private(set) var messages: [Message] = []
    private(set) var isWaiting = false
    private(set) var error: AskAIError?
    var draft = ""

    /// Longest message a student can send (keeps requests small).
    static let maxDraftLength = 500

    private let client: any AskAIClient

    init(context: AskAIContext, client: any AskAIClient) {
        self.context = context
        self.client = client
    }

    /// The session to show for `context`: the existing one if it is for the
    /// same question or exercise, otherwise a fresh one (the old chat is gone).
    static func reusing(_ existing: AskAISession?, for context: AskAIContext, client: any AskAIClient) -> AskAISession {
        if let existing, existing.context.id == context.id { return existing }
        return AskAISession(context: context, client: client)
    }

    var canSend: Bool {
        !isWaiting && !messages.isEmpty
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Opens the chat: sends the hidden problem and shows the greeting.
    /// Does nothing once the chat has started.
    func start() async {
        guard messages.isEmpty, !isWaiting, error == nil else { return }
        await requestReply()
    }

    func send() async {
        let text = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxDraftLength))
        guard canSend, !text.isEmpty else { return }
        draft = ""
        messages.append(Message(role: .student, text: text))
        await requestReply()
    }

    /// Repeats the request that failed (the greeting or the last question).
    func retry() async {
        guard error != nil, !isWaiting else { return }
        await requestReply()
    }

    /// System prompt, then the hidden problem, then the visible chat.
    func turns() -> [ChatTurn] {
        [ChatTurn(role: .system, content: AskAIPrompt.system), ChatTurn(role: .user, content: context.problem)]
            + messages.map { ChatTurn(role: $0.role == .student ? .user : .assistant, content: $0.text) }
    }

    private func requestReply() async {
        isWaiting = true
        error = nil
        defer { isWaiting = false }
        let isGreeting = messages.isEmpty
        do {
            var reply = try await client.complete(turns())
            if isGreeting {
                // The first reply must be a one-line greeting (S39).
                if reply.contains("\n") || reply.count > 160 || AnswerLeakGuard.leaks(reply, context: context) {
                    reply = AskAIPrompt.greeting
                }
            } else if AnswerLeakGuard.leaks(reply, context: context) {
                // One rewrite; if that leaks too, a fixed refusal.
                let rewritten = try await client.complete(turns() + [
                    ChatTurn(role: .assistant, content: "[draft withheld]"),
                    ChatTurn(role: .user, content: "[Sent by the app.] " + AskAIPrompt.rewrite),
                ])
                reply = AnswerLeakGuard.leaks(rewritten, context: context) ? AskAIPrompt.refusal : rewritten
            }
            messages.append(Message(role: .tutor, text: reply))
        } catch {
            self.error = error
        }
    }
}

/// Picks the Ask AI client: none without a key (the button is hidden),
/// the stub under `-UITestAskAIStub`, otherwise OpenRouter.
enum AskAI {
    static let client: (any AskAIClient)? = makeClient(config: .current, arguments: ProcessInfo.processInfo.arguments)

    static func makeClient(config: AppConfig, arguments: [String]) -> (any AskAIClient)? {
        #if DEBUG
            if arguments.contains("-UITestAskAIStub") { return StubAskAIClient() }
        #endif
        guard config.isAskAIConfigured else { return nil }
        return OpenRouterClient(apiKey: config.openRouterAPIKey, model: config.openRouterModel)
    }
}

#if DEBUG
    /// Canned replies for UI tests and previews: no network.
    struct StubAskAIClient: AskAIClient {
        func complete(_ turns: [ChatTurn]) async throws(AskAIError) -> String {
            try? await Task.sleep(for: .milliseconds(300))
            // System prompt + hidden problem only: the opening greeting.
            if turns.count <= 2 { return AskAIPrompt.greeting }
            return """
                Good question. Think about **when** each step runs:
                - A loop repeats its body
                  - until its condition becomes false
                - A function call pauses the caller

                ```
                [ caller ] --calls--> [ helper ]
                ```

                What happens to the caller while the helper runs?
                """
        }
    }
#endif
