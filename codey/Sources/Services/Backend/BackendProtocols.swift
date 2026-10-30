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

/// One sync_log row (R2 audit ledger).
struct SyncLogEntry: Equatable, Sendable {
    var entity: SyncEntity
    var entityId: UUID
    var op: SyncOperationKind
    var clientTimestamp: Date
    var deviceId: String?
}

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
