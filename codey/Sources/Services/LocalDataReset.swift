import Foundation
import SwiftData
import os

/// The two "Danger Zone" actions (Stage 0.5).
enum LocalDataReset {
    /// Zeroes XP and streak and clears card mastery. Content, decks, and the
    /// profile's identity stay. (Quiz question progress joins in Stage 6.)
    static func resetProgress(context: ModelContext) throws {
        let profile = DataSeeder.ensureProfile(context: context)
        profile.totalXP = 0
        profile.currentStreak = 0
        profile.lastActiveDate = nil

        for card in try context.fetch(FetchDescriptor<Flashcard>()) {
            card.resetMastery()
        }
        try context.save()
        Logger.settings.notice("Progress reset by user")
    }

    /// Deletes everything local (profile, decks, cards, quiz content), then
    /// re-seeds bundled content and a fresh profile. The auth session is not
    /// touched; once sign-in exists (Stage 9) the UI must require sign-out
    /// first.
    static func eraseAllLocalData(context: ModelContext, bank: QuestionBank) throws {
        try deleteAll(FlashcardDeck.self, context: context)
        try deleteAll(Flashcard.self, context: context)
        try deleteAll(UserProfile.self, context: context)
        try deleteAll(Question.self, context: context)
        try deleteAll(Topic.self, context: context)
        try context.save()

        try DataSeeder.seed(context: context, bank: bank)
        Logger.settings.notice("All local data erased by user")
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }
}
