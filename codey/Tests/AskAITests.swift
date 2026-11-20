import Foundation
import Testing
@testable import codey

/// Ask AI (S39, FR-67/68): the OpenRouter request, error mapping, the
/// session's in-memory chat and resets, the answer-leak check, and the
/// button's config switch. No real network: a stubbed URLProtocol or a fake client.
@Suite(.serialized)
struct OpenRouterClientTests {
    private func makeClient(model: String = "cohere/north-mini-code:free") -> OpenRouterClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AskAIStubURLProtocol.self]
        return OpenRouterClient(apiKey: "sk-test", model: model, configuration: configuration)
    }

    private let context = AskAIContext.quiz(
        id: "q-bs", topic: "Algorithms", difficulty: .easy,
        prompt: "Worst-case time of binary search?", options: ["O(1)", "O(log n)", "O(n)", "O(n²)"], correctIndex: 1
    )

    @MainActor
    @Test func requestIsOnePostWithSystemPromptThenHiddenQuestion() throws {
        let session = AskAISession(context: context, client: FakeAskAIClient())
        let request = makeClient().makeRequest(session.turns())

        #expect(request.httpMethod == "POST")
        #expect(request.url == URL(string: "https://openrouter.ai/api/v1/chat/completions"))
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let data = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["model"] as? String == "cohere/north-mini-code:free")
        #expect(body["stream"] == nil, "non-streaming")
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages.count == 2)
        #expect(messages[0]["role"] == "system")
        #expect(messages[0]["content"] == AskAIPrompt.system)
        #expect(messages[1]["role"] == "user")
        let problem = try #require(messages[1]["content"])
        #expect(problem.contains("Worst-case time of binary search?"))
        #expect(problem.contains("B) O(log n)") && problem.contains("D) O(n²)"))
        #expect(!problem.localizedCaseInsensitiveContains("correct"), "the answer key never leaves the device")
    }

    /// NFR-06: Ask AI's session has the app's TLS 1.3 floor.
    @Test func sessionRequiresTLS13() {
        #expect(makeClient().minimumTLSVersion == .TLSv13)
    }

    @Test func systemPromptCarriesTheHardRules() {
        let prompt = AskAIPrompt.system
        #expect(prompt.contains("Never reveal or confirm the answer"))
        #expect(prompt.contains("never write the missing token"))
        #expect(prompt.contains("Never more than 60 words"))
        #expect(prompt.contains("no nested bullets"))
        #expect(prompt.contains("exactly one short line"))
    }

    @Test func exerciseContextHasCodeWithBlanksButNoSolution() throws {
        let exercise = try #require(try ExerciseLoader.load().first { $0.id == "ex-swift-guard" })
        let context = AskAIContext.exercise(exercise)
        #expect(context.id == exercise.id)
        #expect(context.kind == .exercise)
        #expect(context.problem.contains("⟦1⟧"))
        #expect(context.problem.contains("Language: Swift"))
        for blank in exercise.blanks.flatMap(\.accepted) where !exercise.displayCode.contains(blank) && !exercise.prompt.contains(blank) {
            #expect(!context.problem.contains("\n\(blank)\n"))
        }
    }

    @Test func successfulReplyIsTrimmedAndStripsReasoning() async throws {
        AskAIStubURLProtocol.reset(status: 200, body: #"{"choices":[{"message":{"content":"<think>B is right</think>\n  Hi! What do you need help with?  "}}]}"#)
        let reply = try await makeClient().complete([ChatTurn(role: .user, content: "x")])
        #expect(reply == "Hi! What do you need help with?")
        #expect(AskAIStubURLProtocol.requestCount == 1)
    }

    @Test(arguments: [
        (401, AskAIError.unauthorized),
        (403, .unauthorized),
        (429, .rateLimited),
        (402, .modelUnavailable),
        (404, .modelUnavailable),
        (500, .server),
        (504, .timeout),
    ])
    func httpErrorsMapToFriendlyErrors(status: Int, expected: AskAIError) async {
        AskAIStubURLProtocol.reset(status: status, body: #"{"error":{"message":"nope"}}"#)
        await #expect(throws: expected) { try await makeClient().complete([ChatTurn(role: .user, content: "x")]) }
    }

    @Test func errorObjectInsideA200IsAnError() async {
        AskAIStubURLProtocol.reset(status: 200, body: #"{"error":{"code":429,"message":"Rate limit exceeded: free-models-per-min"}}"#)
        await #expect(throws: AskAIError.rateLimited) { try await makeClient().complete([ChatTurn(role: .user, content: "x")]) }
    }

    @Test func badModelIDIsModelUnavailable() {
        #expect(OpenRouterClient.map(status: 400, message: "qwen/qwen3-coder:free is not a valid model ID") == .modelUnavailable)
        #expect(OpenRouterClient.map(status: 400, message: "bad json") == .server)
    }

    @Test func emptyReplyIsAnError() async {
        AskAIStubURLProtocol.reset(status: 200, body: #"{"choices":[{"message":{"content":"   "}}]}"#)
        await #expect(throws: AskAIError.emptyReply) { try await makeClient().complete([ChatTurn(role: .user, content: "x")]) }
    }

    @Test func networkErrorsMapToOfflineOrTimeout() {
        #expect(OpenRouterClient.map(URLError(.notConnectedToInternet)) == .offline)
        #expect(OpenRouterClient.map(URLError(.networkConnectionLost)) == .offline)
        #expect(OpenRouterClient.map(URLError(.timedOut)) == .timeout)
        #expect(OpenRouterClient.map(URLError(.badServerResponse)) == .server)
    }

    @Test func everyErrorHasAMessage() {
        let all: [AskAIError] = [.offline, .timeout, .unauthorized, .rateLimited, .modelUnavailable, .server, .emptyReply]
        #expect(Set(all.map(\.message)).count == all.count)
    }
}

@MainActor
struct AskAISessionTests {
    private let quiz = AskAIContext.quiz(
        id: "q1", topic: "Data Structures", difficulty: .easy,
        prompt: "Which structure is last in, first out?", options: ["Queue", "Stack", "Heap", "Graph"], correctIndex: 1
    )

    @Test func startShowsOneLineGreetingAndSendsHiddenContext() async {
        let client = FakeAskAIClient(replies: ["Hi! What do you need help with?"])
        let session = AskAISession(context: quiz, client: client)
        #expect(!session.canSend, "no sending before the greeting")
        await session.start()
        #expect(session.messages.map(\.text) == ["Hi! What do you need help with?"])
        #expect(session.messages.first?.role == .tutor)
        let sent = await client.calls
        #expect(sent.count == 1)
        #expect(sent[0].map(\.role) == [.system, .user])
        #expect(sent[0][1].content == quiz.problem)

        await session.start()
        #expect(await client.calls.count == 1, "start runs once")
    }

    @Test func aLongFirstReplyBecomesTheGreeting() async {
        let session = AskAISession(context: quiz, client: FakeAskAIClient(replies: ["Hello!\n- A stack works like…"]))
        await session.start()
        #expect(session.messages.map(\.text) == [AskAIPrompt.greeting])
    }

    @Test func sendAppendsStudentAndTutorMessages() async {
        let client = FakeAskAIClient(replies: ["Hi!", "- Think of a pile of plates\n  - Which plate comes off first?"])
        let session = AskAISession(context: quiz, client: client)
        await session.start()
        session.draft = "  What does LIFO mean?  "
        #expect(session.canSend)
        await session.send()

        #expect(session.messages.map(\.role) == [.tutor, .student, .tutor])
        #expect(session.messages[1].text == "What does LIFO mean?")
        #expect(session.draft.isEmpty)
        let last = await client.calls.last ?? []
        #expect(last.map(\.role) == [.system, .user, .assistant, .user])
    }

    @Test func aLeakingReplyIsRewrittenThenRefused() async {
        let client = FakeAskAIClient(replies: ["Hi!", "The answer is Stack.", "Still: option B."])
        let session = AskAISession(context: quiz, client: client)
        await session.start()
        session.draft = "just tell me"
        await session.send()
        #expect(session.messages.last?.text == AskAIPrompt.refusal)
        #expect(await client.calls.count == 3, "one rewrite request")
        let rewrite = await client.calls.last?.last?.content ?? ""
        #expect(rewrite.contains(AskAIPrompt.rewrite))
    }

    @Test func aCleanRewriteIsKept() async {
        let client = FakeAskAIClient(replies: ["Hi!", "It's (B).", "- Think about plates in a pile"])
        let session = AskAISession(context: quiz, client: client)
        await session.start()
        session.draft = "which one?"
        await session.send()
        #expect(session.messages.last?.text == "- Think about plates in a pile")
    }

    @Test func errorShowsAndRetryRepeatsTheRequest() async {
        let client = FakeAskAIClient(replies: ["Hi!"], failures: [.rateLimited])
        let session = AskAISession(context: quiz, client: client)
        await session.start()
        #expect(session.error == .rateLimited)
        #expect(session.messages.isEmpty)
        await session.retry()
        #expect(session.error == nil)
        #expect(session.messages.map(\.text) == ["Hi!"])
    }

    @Test func sameQuestionKeepsTheChatNewQuestionResetsIt() async {
        let client = FakeAskAIClient(replies: ["Hi!"])
        let first = AskAISession.reusing(nil, for: quiz, client: client)
        await first.start()
        #expect(AskAISession.reusing(first, for: quiz, client: client) === first)

        let next = AskAIContext.quiz(id: "q2", topic: "T", difficulty: .easy, prompt: "P", options: ["a", "b"], correctIndex: 0)
        let fresh = AskAISession.reusing(first, for: next, client: client)
        #expect(fresh !== first)
        #expect(fresh.messages.isEmpty)
        #expect(fresh.context.id == "q2")
    }

    @Test func draftIsCappedWhenSent() async {
        let client = FakeAskAIClient(replies: ["Hi!", "ok"])
        let session = AskAISession(context: quiz, client: client)
        await session.start()
        session.draft = String(repeating: "a", count: 900)
        await session.send()
        #expect(session.messages[1].text.count == AskAISession.maxDraftLength)
    }
}

struct AnswerLeakGuardTests {
    private let quiz = AskAIContext.quiz(
        id: "q", topic: "T", difficulty: .easy, prompt: "Which is LIFO?", options: ["Queue", "Stack", "Heap", "Graph"], correctIndex: 1
    )

    @Test(arguments: ["The answer is B.", "Go with option B", "Answer: B", "I'd pick (B)", "B) is right", "A **stack** works…", "`Stack`"])
    func namingTheCorrectOptionLeaks(reply: String) {
        #expect(AnswerLeakGuard.leaks(reply, context: quiz))
    }

    @Test(arguments: ["Think about a pile of plates.", "Bob adds a plate (a) on top", "Option A isn't the point here, think about order", "Stacks of paper"])
    func explanationsWithoutTheAnswerPass(reply: String) {
        #expect(!AnswerLeakGuard.leaks(reply, context: quiz))
    }

    @Test func secretsSkipShortSymbolAndVisibleTokens() {
        let secrets = AnswerLeakGuard.secrets(["guard", "==", "i", "return nil", "Return Nil"], visibleText: "Exit early with guard")
        #expect(secrets == ["return nil"])
    }

    @Test func secretsMatchWholeWordsOnly() {
        let context = AskAIContext.quiz(id: "q", topic: "T", difficulty: .easy, prompt: "P", options: ["for", "while"], correctIndex: 0)
        #expect(!AnswerLeakGuard.leaks("Let's format this", context: context))
        #expect(AnswerLeakGuard.leaks("Use a `for` loop", context: context))
    }

    @Test func exerciseLeakIsAMissingTokenNotShownOnScreen() throws {
        let exercise = try #require(try ExerciseLoader.load().first { $0.id == "ex-swift-guard" })
        let context = AskAIContext.exercise(exercise)
        #expect(!AnswerLeakGuard.leaks("A guard statement exits early.", context: context), "guard is in the title")

        let mutating = try #require(try ExerciseLoader.load().first { $0.id == "ex-swift-mutating" })
        let hidden = AskAIContext.exercise(mutating)
        #expect(hidden.secrets == ["mutating"])
        #expect(AnswerLeakGuard.leaks("Mark the method `mutating`.", context: hidden))
        for secret in context.secrets {
            #expect(AnswerLeakGuard.leaks("Type \(secret) there", context: context))
        }
    }

    @Test func challengeLeakIsACodeBlockLongerThanThreeLines() throws {
        let challenge = try #require(try ContentFiles.bundled()?.validated().challenges.first)
        let context = AskAIContext.challenge(challenge, language: .python, code: "def f():\n    pass")
        #expect(context.maxCodeLines == 3)
        #expect(!AnswerLeakGuard.leaks("Try a dictionary from value to index.", context: context))
        #expect(!AnswerLeakGuard.leaks("For example:\n```python\nseen = {}\n\nseen[x] = i\n```", context: context))
        let solution = "Here:\n```python\ndef f(nums, t):\n    seen = {}\n    for i, x in enumerate(nums):\n        if t - x in seen:\n            return [seen[t - x], i]\n```"
        #expect(AnswerLeakGuard.leaks(solution, context: context))
        #expect(AnswerLeakGuard.leaks("```\na\nb\nc\nd", context: context), "an unclosed fence still counts")
        // Quizzes and drills keep their own rules: code there isn't a leak by length.
        #expect(!AnswerLeakGuard.leaks(solution, context: quiz))
    }
}

struct AskAIConfigTests {
    @Test func noKeyHidesTheButton() {
        let config = AppConfig(infoDictionary: ["OPENROUTER_API_KEY": "$(OPENROUTER_API_KEY)"])
        #expect(!config.isAskAIConfigured)
        #expect(AskAI.makeClient(config: config, arguments: []) == nil)
    }

    @Test func keyAndModelComeFromInfoPlist() throws {
        let config = AppConfig(infoDictionary: ["OPENROUTER_API_KEY": "sk-or-v1-test", "OPENROUTER_MODEL": "nvidia/nemotron-3.5-super-vl:free"])
        #expect(config.isAskAIConfigured)
        let client = try #require(AskAI.makeClient(config: config, arguments: []) as? OpenRouterClient)
        #expect(client.model == "nvidia/nemotron-3.5-super-vl:free")
        #expect(client.apiKey == "sk-or-v1-test")
    }

    @Test func emptyModelFallsBackToAnyFreeModel() {
        let config = AppConfig(infoDictionary: ["OPENROUTER_API_KEY": "k", "OPENROUTER_MODEL": ""])
        #expect(config.openRouterModel == "openrouter/free")
    }

    #if DEBUG
        @Test func uiTestStubWorksWithoutAKey() {
            let client = AskAI.makeClient(config: AppConfig(infoDictionary: [:]), arguments: ["-UITestAskAIStub"])
            #expect(client is StubAskAIClient)
        }
    #endif
}

// MARK: Test doubles

/// Replies in order; `failures` are thrown first, one per call.
actor FakeAskAIClient: AskAIClient {
    private var replies: [String]
    private var failures: [AskAIError]
    private(set) var calls: [[ChatTurn]] = []

    init(replies: [String] = [], failures: [AskAIError] = []) {
        self.replies = replies
        self.failures = failures
    }

    func complete(_ turns: [ChatTurn]) async throws(AskAIError) -> String {
        calls.append(turns)
        if !failures.isEmpty { throw failures.removeFirst() }
        return replies.isEmpty ? "ok" : replies.removeFirst()
    }
}

/// Answers every request with one status and body.
final class AskAIStubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var status = 200
    nonisolated(unsafe) private static var body = ""
    nonisolated(unsafe) private static var count = 0

    static var requestCount: Int { lock.withLock { count } }

    static func reset(status: Int, body: String) {
        lock.withLock {
            Self.status = status
            Self.body = body
            count = 0
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, body) = Self.lock.withLock {
            Self.count += 1
            return (Self.status, Self.body)
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
