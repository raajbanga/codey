import Foundation

/// Run = the example tests; Submit = every test, hidden ones too (FR-70, FR-71).
enum ChallengeRunMode: String, Codable, Sendable {
    case run, submit
}

struct ChallengeRunRequest: Encodable, Sendable {
    let challengeId: String
    let language: CodeLanguage
    let code: String
    let mode: ChallengeRunMode
}

/// What run-challenge returns (supabase/functions/run-challenge/judge.ts).
struct ChallengeVerdict: Decodable, Equatable, Sendable {
    enum Status: String, Decodable, Sendable {
        case accepted
        case wrongAnswer = "wrong_answer"
        case compileError = "compile_error"
        case runtimeError = "runtime_error"
        case timeLimit = "time_limit"
    }

    struct Test: Decodable, Equatable, Sendable, Identifiable {
        enum Status: String, Decodable, Sendable {
            case passed, failed, error
            case notRun = "not_run"
        }

        let ordinal: Int
        let hidden: Bool
        let status: Status
        /// Example tests only.
        let input: String?
        let expected: JSONValue?
        let actual: JSONValue?
        let error: String?

        var id: Int { ordinal }
    }

    let status: Status
    let passedCount: Int
    let total: Int
    let tests: [Test]
    let stdout: String
    let stderr: String
    let compileOutput: String
    let mode: ChallengeRunMode
    let elapsedMs: Int?

    var isAccepted: Bool { status == .accepted }
}

/// Why a run couldn't happen (not a verdict on the code).
enum ChallengeRunError: Error, Equatable, LocalizedError {
    case offline
    case notConfigured
    case rateLimited(String)
    case runnerDown(String)
    case other(String)

    var errorDescription: String? {
        switch self {
        case .offline: "Connect to the internet to run your code."
        case .notConfigured: "Running code needs the Codey backend, which this build doesn't have."
        case .rateLimited(let message), .runnerDown(let message), .other(let message): message
        }
    }
}

/// Runs a challenge submission. Live: the run-challenge Edge Function
/// (SupabaseDataClient). UI tests: `StubChallengeRunner`.
protocol ChallengeRunning: Sendable {
    func run(_ request: ChallengeRunRequest) async throws -> ChallengeVerdict
}

enum ChallengeRunnerFactory {
    @MainActor
    static func make(remote: (any RemoteDeckStore)?, arguments: [String] = ProcessInfo.processInfo.arguments) -> (any ChallengeRunning)? {
        #if DEBUG
            if arguments.contains("-UITestRunnerStub") { return StubChallengeRunner() }
        #endif
        return remote.map { RemoteChallengeRunner(remote: $0) }
    }
}

struct RemoteChallengeRunner: ChallengeRunning {
    let remote: any RemoteDeckStore
    func run(_ request: ChallengeRunRequest) async throws -> ChallengeVerdict {
        try await remote.runChallenge(request)
    }
}

/// A JSON value as the runner returns it (arguments, expected and actual
/// results), shown compactly like the examples ("[0,1]").
enum JSONValue: Decodable, Equatable, Sendable, CustomStringConvertible {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    var description: String {
        switch self {
        case .null: return "null"
        case .bool(let value): return value ? "true" : "false"
        case .number(let value):
            if value.rounded() == value, abs(value) < 1e15 { return String(Int64(value)) }
            return String(value)
        case .string(let value):
            let data = (try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .withoutEscapingSlashes])) ?? Data()
            return String(data: data, encoding: .utf8) ?? "\"\(value)\""
        case .array(let values): return "[" + values.map(\.description).joined(separator: ",") + "]"
        case .object(let fields): return "{" + fields.sorted { $0.key < $1.key }.map { "\"\($0.key)\":\($0.value)" }.joined(separator: ",") + "}"
        }
    }
}

#if DEBUG
    /// UI tests: Run fails the second example; Submit is accepted. No network.
    struct StubChallengeRunner: ChallengeRunning {
        func run(_ request: ChallengeRunRequest) async throws -> ChallengeVerdict {
            try await Task.sleep(for: .milliseconds(300))
            let accepted = request.mode == .submit
            return ChallengeVerdict(
                status: accepted ? .accepted : .wrongAnswer,
                passedCount: accepted ? 8 : 1,
                total: accepted ? 8 : 2,
                tests: accepted
                    ? (1...8).map { .init(ordinal: $0, hidden: $0 > 2, status: .passed, input: nil, expected: nil, actual: nil, error: nil) }
                    : [
                        .init(ordinal: 1, hidden: false, status: .passed, input: "nums = [2,7,11,15], target = 9",
                              expected: .array([.number(0), .number(1)]), actual: .array([.number(0), .number(1)]), error: nil),
                        .init(ordinal: 2, hidden: false, status: .failed, input: "nums = [3,2,4], target = 6",
                              expected: .array([.number(1), .number(2)]), actual: .array([]), error: nil),
                    ],
                stdout: accepted ? "" : "debugging [3, 2, 4]",
                stderr: "",
                compileOutput: "",
                mode: request.mode,
                elapsedMs: 300
            )
        }
    }
#endif
