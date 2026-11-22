import Foundation
import UIKit

// MARK: - [Pattern: Facade] Facade (profile, feedback)
/// Profile identity (FR-04), defect reports (FR-49), the progress-reset
/// push (D10), and whose progress is on the device (BUG-06). Part of the
/// BackendFacade (§9.4).
extension BackendFacade {
    /// FR-04: saves the name and avatar locally and, when signed in, queues
    /// a profile push. A queued profile operation makes the local values win
    /// the next merge (last write wins). Throws the validator's FieldError.
    func updateProfile(displayName: String, avatarId: String?) throws {
        if let error = ModelValidator.validateDisplayName(displayName).first { throw error }
        let profile = DataSeeder.ensureProfile(context: context)
        profile.username = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.avatarId = avatarId.flatMap { ProfileAvatar.parse($0) == nil ? nil : $0 }
        if let userID {
            try queue.enqueue(.profile, id: profile.id, op: .upsert, ownerId: userID)
        }
        try persist()
    }

    /// FR-49: sends a UI/UX issue report. Signed-in only (RLS ties the row
    /// to the account). Not queued: on failure the form keeps the text and
    /// shows the error, so the user can retry when back online.
    func submitFeedback(_ text: String) async throws {
        guard let remote, currentUser != nil else { throw FeedbackError.signInRequired }
        if let error = ModelValidator.validateFeedback(text).first { throw error }
        try await remote.submitFeedback(FeedbackReportPayload(
            id: UUID(),
            description: text.trimmingCharacters(in: .whitespacesAndNewlines),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            osVersion: UIDevice.current.systemVersion
        ))
    }

    /// "Reset progress" writes XP 0 explicitly instead of max-merging (D10).
    func didResetProgress() {
        guard let userID else { return }
        let profile = DataSeeder.ensureProfile(context: context)
        try? queue.enqueue(.profile, id: profile.id, op: .upsert, ownerId: userID)
        try? persist()
    }

    /// BUG-06: the progress on the device belongs to the account that last
    /// signed in (kept even if its session ends without a sign-out). When a
    /// different account signs in, that progress (synced to its owner, or
    /// lost with its unsynced part) is cleared before the first sync merges
    /// the device's progress into the new account. The same account signing
    /// back in keeps it all.
    func clearProgress(ifOwnedByAnotherAccountThan userID: UUID) throws {
        if let owner = cursors.progressOwner, owner != userID {
            do {
                // A queued profile update would push the cleared XP to its account.
                try queue.remove(.profile, ids: [DataSeeder.ensureProfile(context: context).id])
                try LocalDataReset.resetProgress(context: context, weeklyXP: weeklyXP)
            } catch {
                context.rollback()
                throw error
            }
            // This account's own progress may have been cleared here before
            // (its session ended without a sign-out): pull and push it all.
            for key in [SyncCursorStore.Key.progressCursor, .progressPushedAt, .historyPushedAt] {
                cursors.set(nil, key, for: userID)
            }
        }
        cursors.progressOwner = userID
    }
}

/// FR-49 failures the form explains.
enum FeedbackError: LocalizedError {
    case signInRequired

    var errorDescription: String? {
        switch self {
        case .signInRequired: "Sign in to send a report."
        }
    }
}
