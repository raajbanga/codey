import Foundation
import UIKit

// MARK: - [Pattern: Facade] Facade (profile, feedback)
/// Profile identity (FR-04), defect reports (FR-49) and the progress-reset
/// push (D10). Part of the BackendFacade (§9.4).
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
