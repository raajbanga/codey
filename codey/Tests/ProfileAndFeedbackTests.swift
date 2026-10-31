import Foundation
import SwiftData
import Testing
@testable import codey

/// FR-04 (display name + avatar) and FR-49 (UI/UX issue reports).
@MainActor
struct ProfileAndFeedbackTests {

    // MARK: Validator limits (±1)

    @Test func displayNameLimits() {
        let validator = ModelValidator()
        #expect(validator.validateDisplayName(String(repeating: "a", count: 30)).isEmpty)
        #expect(validator.validateDisplayName(String(repeating: "a", count: 31)).first?.reason == .tooLong(max: 30, actual: 31))
        #expect(validator.validateDisplayName("   ").first?.reason == .empty)
        // Counted after trimming, in Unicode scalars (matches char_length).
        #expect(validator.validateDisplayName("  " + String(repeating: "é", count: 30) + "  ").isEmpty)
    }

    @Test func feedbackLimits() {
        let validator = ModelValidator()
        #expect(validator.validateFeedback(String(repeating: "x", count: 1_000)).isEmpty)
        #expect(validator.validateFeedback(String(repeating: "x", count: 1_001)).first?.reason == .tooLong(max: 1_000, actual: 1_001))
        #expect(validator.validateFeedback("\n").first?.reason == .empty)
    }

    // MARK: FR-04

    @Test func profileEditIsSavedAndWinsTheNextSync() async throws {
        let h = try SyncHarness()
        h.remote.profile = ProfilePayload(displayName: "Alice", avatarId: "moon.fill", totalXP: 0)

        try h.facade.updateProfile(displayName: "  Bea  ", avatarId: "star.fill")
        let profile = DataSeeder.ensureProfile(context: h.context)
        #expect(profile.username == "Bea")
        #expect(profile.avatarId == "star.fill")

        #expect(await h.engine.syncNow())
        #expect(h.remote.profile == ProfilePayload(displayName: "Bea", avatarId: "star.fill", totalXP: 0))
    }

    @Test func withoutALocalEditTheRemoteAvatarWins() async throws {
        let h = try SyncHarness()
        h.remote.profile = ProfilePayload(displayName: "Alice", avatarId: "moon.fill", totalXP: 0)

        #expect(await h.engine.syncNow())
        #expect(DataSeeder.ensureProfile(context: h.context).avatarId == "moon.fill")
    }

    @Test func invalidProfileEditsAreRejected() throws {
        let h = try SyncHarness(user: nil)
        #expect(throws: FieldError.self) {
            try h.facade.updateProfile(displayName: String(repeating: "a", count: 31), avatarId: nil)
        }
        // An avatar outside the set is dropped, not stored.
        try h.facade.updateProfile(displayName: "Guest", avatarId: "skull.fill")
        #expect(DataSeeder.ensureProfile(context: h.context).avatarId == nil)
        // Guests don't queue a profile push.
        #expect(h.queue.pendingCount(ownerId: nil) == 0)
    }

    @Test func avatarSymbolFallsBackForUnknownValues() {
        #expect(ProfileAvatar.symbol(for: "star.fill") == "star.fill")
        #expect(ProfileAvatar.symbol(for: "skull.fill") == ProfileAvatar.fallback)
        #expect(ProfileAvatar.symbol(for: nil) == ProfileAvatar.fallback)
        #expect(ProfileAvatar.symbols.count == 12)
    }

    // MARK: FR-49

    @Test func feedbackNeedsSignIn() async throws {
        let h = try SyncHarness(user: nil)
        await #expect(throws: FeedbackError.self) {
            try await h.facade.submitFeedback("The quiz button overlaps the text")
        }
        #expect(h.remote.feedback.isEmpty)
    }

    @Test func feedbackIsValidatedTrimmedAndSent() async throws {
        let h = try SyncHarness()
        await #expect(throws: FieldError.self) { try await h.facade.submitFeedback("   ") }

        try await h.facade.submitFeedback("  The quiz button overlaps the text \n")
        let report = try #require(h.remote.feedback.first)
        #expect(report.description == "The quiz button overlaps the text")
        #expect(report.osVersion != nil)
    }

    @Test func offlineFeedbackThrowsSoTheFormKeepsTheText() async throws {
        let h = try SyncHarness()
        h.remote.isOffline = true
        await #expect(throws: (any Error).self) { try await h.facade.submitFeedback("Text is clipped") }
        #expect(h.remote.feedback.isEmpty)
    }
}
