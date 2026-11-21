import Foundation
import UIKit

// Subsystems behind the BackendFacade (§9.4). Each is a protocol so the facade
// and SyncEngine can be tested with mocks and no network (R7). Only
// Services/Backend/Supabase/ implements the remote ones with Supabase and
// GoogleSignIn.

/// The signed-in account, as the UI sees it.
struct AppUser: Equatable, Sendable {
    let id: UUID
    let email: String?
    let displayName: String?
}

// MARK: - [Pattern: Facade] Subsystem (auth)
/// Google sign-in → Supabase session (FR-01–03). The session lives in the
/// Keychain (FR-02).
@MainActor
protocol AuthProviding: AnyObject {
    /// nil when the user cancels the Google sheet.
    func signIn(presenting viewController: UIViewController) async throws -> AppUser?
    /// Ends the Supabase and Google sessions and removes the stored session (FR-03).
    func signOut() async
    /// The restored or current user, if any.
    func currentUser() -> AppUser?
    func currentUserID() -> UUID?
    /// Emits on sign-in, sign-out, and session expiry.
    func authStateStream() -> AsyncStream<AppUser?>
    /// Forwards the Google OAuth redirect. Returns whether it was handled.
    func handle(_ url: URL) -> Bool
}

/// A deck row as it travels to and from the server.
struct DeckPayload: Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var topicId: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    /// Set by the server; nil when pushing.
    var serverUpdatedAt: Date?
}

/// A card row: the shared FlashcardPayload plus its deck.
struct RemoteCard: Equatable, Sendable {
    var deckId: UUID
    var card: FlashcardPayload
}

/// Everything changed on the server since a cursor.
struct RemoteChanges: Equatable, Sendable {
    var decks: [DeckPayload]
    var cards: [RemoteCard]
    /// The largest server_updated_at seen; the next pull cursor.
    var cursor: Date?
}

/// One deck with all of its cards (tombstones included), for the merge.
struct RemoteDeckSnapshot: Equatable, Sendable {
    var deck: DeckPayload
    var cards: [RemoteCard]
}

/// The synced profile fields (D10).
struct ProfilePayload: Equatable, Sendable {
    var displayName: String
    var avatarId: String?
    var totalXP: Int
    /// FR-61 (S43): exercises already paid for; merged as a union.
    var solvedExerciseIds: [String] = []
}

/// FR-49: one UI/UX issue report. The id is made on the device, so a
/// retried send can't create a duplicate.
struct FeedbackReportPayload: Equatable, Sendable {
    var id: UUID
    var description: String
    var appVersion: String?
    var osVersion: String?
}

/// FR-50: a leaderboard group you're in.
struct GroupSummary: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var inviteCode: String
}

/// FR-42: one member's XP this UTC week (group_leaderboard view).
struct LeaderboardEntry: Codable, Equatable, Identifiable, Sendable {
    var userId: UUID
    var displayName: String
    var avatarId: String?
    var xp: Int

    var id: UUID { userId }
}

/// FR-50–52 failures the group screens explain.
enum GroupError: LocalizedError, Equatable {
    case signInRequired
    case invalidCode
    case notFound

    var errorDescription: String? {
        switch self {
        case .signInRequired: "Sign in to use groups."
        case .invalidCode: "No group has that code. Check it and try again."
        case .notFound: "That group isn't available anymore."
        }
    }
}

/// FR-61: one card's study progress (card_progress). Latest review wins.
struct CardProgressPayload: Equatable, Sendable {
    var cardId: UUID
    var masteryScore: Int
    var lastReviewedAt: Date
    var retiredAt: Date?
}

/// FR-61: one quiz question's progress (question_progress). Latest answer wins.
struct QuestionProgressPayload: Equatable, Sendable {
    var questionId: String
    var topicId: String
    var difficulty: Difficulty
    var consecutiveCorrect: Int
    var totalAttempts: Int
    var totalCorrect: Int
    var retiredAt: Date?
    var isReview: Bool
    var lastAnsweredAt: Date
}

/// FR-61: tier unlocks for one topic (topic_progress). Sticky: earliest wins.
struct TopicProgressPayload: Equatable, Sendable {
    var topicId: String
    var mediumUnlockedAt: Date?
    var hardUnlockedAt: Date?
}

/// FR-61: one graded quiz answer (quiz_answers). Append-only; the question
/// and time identify it.
struct QuizAnswerPayload: Equatable, Sendable {
    var questionId: String
    var topicId: String
    var correct: Bool
    var answeredAt: Date
}

/// FR-61: one device's counters for one local day (daily_activity). The
/// larger counter wins; a day's total is the sum over devices.
struct DailyActivityPayload: Equatable, Sendable {
    var deviceId: String
    var day: String
    var cardsRated: Int
    var quizAnswers: Int
}

/// FR-61: one earned badge (badge_awards). The earliest date wins.
struct BadgeAwardPayload: Equatable, Sendable {
    var badge: String
    var earnedAt: Date
}

/// FR-61: progress rows going up or coming down in one sync cycle.
struct ProgressBatch: Equatable, Sendable {
    var cards: [CardProgressPayload] = []
    var questions: [QuestionProgressPayload] = []
    var topics: [TopicProgressPayload] = []
    var answers: [QuizAnswerPayload] = []
    var days: [DailyActivityPayload] = []
    var badges: [BadgeAwardPayload] = []

    var isEmpty: Bool { count == 0 }
    var count: Int {
        cards.count + questions.count + topics.count + answers.count + days.count + badges.count
    }

    /// Rows not already in `other` (drops echoes of what was just pulled).
    func subtracting(_ other: ProgressBatch) -> ProgressBatch {
        ProgressBatch(
            cards: cards.filter { !other.cards.contains($0) },
            questions: questions.filter { !other.questions.contains($0) },
            topics: topics.filter { !other.topics.contains($0) },
            answers: answers.filter { !other.answers.contains($0) },
            days: days.filter { !other.days.contains($0) },
            badges: badges.filter { !other.badges.contains($0) }
        )
    }
}

/// FR-61: progress changed on the server since a cursor.
struct RemoteProgressChanges: Equatable, Sendable {
    var progress: ProgressBatch
    /// The largest server_updated_at seen; the next progress cursor.
    var cursor: Date?
}

/// One sync_log row (R2 audit ledger).
struct SyncLogEntry: Equatable, Sendable {
    var entity: SyncEntity
    var entityId: UUID
    var op: SyncOperationKind
    var clientTimestamp: Date
    var deviceId: String?
}

// MARK: - [Pattern: Facade] Subsystem (remote store)
/// The Supabase tables, via PostgREST. RLS scopes every call to the signed-in
/// owner. Upserts are one batched request each (NFR-02).
protocol RemoteDeckStore: Sendable {
    /// Returns server_updated_at per deck id.
    func upsertDecks(_ decks: [DeckPayload]) async throws -> [UUID: Date]
    func upsertCards(_ cards: [RemoteCard]) async throws
    func fetchChanges(since cursor: Date?) async throws -> RemoteChanges
    /// server_updated_at for each deck that exists remotely (conflict check).
    func fetchDeckVersions(ids: [UUID]) async throws -> [UUID: Date]
    func fetchDeckSnapshot(id: UUID) async throws -> RemoteDeckSnapshot?
    func fetchProfile() async throws -> ProfilePayload?
    func upsertProfile(_ profile: ProfilePayload) async throws
    func appendSyncLog(_ entries: [SyncLogEntry]) async throws
    /// FR-49: insert-only; users can't read reports back (RLS).
    func submitFeedback(_ report: FeedbackReportPayload) async throws

    // FR-42, FR-50–52: groups and the weekly leaderboard.
    /// Groups the signed-in user is a member of.
    func fetchGroups() async throws -> [GroupSummary]
    /// The server picks the invite code and adds the creator as a member.
    func createGroup(id: UUID, name: String) async throws -> GroupSummary
    /// join_group(code). Throws GroupError.invalidCode for an unknown code.
    func joinGroup(code: String) async throws -> GroupSummary
    func leaveGroup(id: UUID) async throws
    func fetchLeaderboard(groupID: UUID) async throws -> [LeaderboardEntry]
    /// Max-merged on the server (weekly_xp trigger).
    func upsertWeeklyXP(weekStart: String, xp: Int) async throws

    // FR-61: study progress.
    /// Progress rows changed after `cursor` (all of them when nil).
    func fetchProgressChanges(since cursor: Date?) async throws -> RemoteProgressChanges
    /// Merged on the server: older reviews are skipped, unlocks are sticky.
    func upsertProgress(_ batch: ProgressBatch) async throws

    /// The teaching content (content_* tables), public to every client.
    func fetchContent() async throws -> ContentFiles

    /// Runs code for a coding challenge on the Codey runner (S45, FR-70/71).
    func runChallenge(_ request: ChallengeRunRequest) async throws -> ChallengeVerdict
}

extension RemoteDeckStore {
    /// Fakes without content: the app keeps what it has.
    func fetchContent() async throws -> ContentFiles { throw URLError(.resourceUnavailable) }
    /// Fakes can't run code.
    func runChallenge(_ request: ChallengeRunRequest) async throws -> ChallengeVerdict { throw ChallengeRunError.notConfigured }
}

/// Network reachability (NWPathMonitor in the app).
@MainActor
protocol Reachability: AnyObject {
    var isReachable: Bool { get }
    /// Emits on every change.
    func changes() -> AsyncStream<Bool>
}

extension FlashcardDeck {
    func toPayload() -> DeckPayload {
        DeckPayload(
            id: id,
            title: title,
            topicId: topicId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}
