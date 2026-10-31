import Foundation
import SwiftData
import os

/// The two "Danger Zone" actions (Stage 0.5).
enum LocalDataReset {
    /// Zeroes XP (and this week's XP); clears card mastery, saved study sessions, daily activity
    /// (so the derived streak is 0), badges, and quiz progress (retirement,
    /// tier unlocks, answer history). Content, decks, and the profile's
    /// identity stay.
    static func resetProgress(context: ModelContext, weeklyXP: WeeklyXPStore = WeeklyXPStore()) throws {
        let profile = DataSeeder.ensureProfile(context: context)
        profile.totalXP = 0

        for card in try context.fetch(FetchDescriptor<Flashcard>()) {
            card.resetMastery()
        }
        try deleteAll(StudyProgressSnapshot.self, context: context)
        try deleteAll(DailyActivity.self, context: context)
        try deleteAll(BadgeAward.self, context: context)
        try deleteQuizProgress(context: context)
        try context.save()
        // The server keeps this week's max (weekly_xp), like total_xp.
        weeklyXP.reset()
        Logger.settings.notice("Progress reset by user")
    }

    /// Deletes everything local (profile, decks, cards, quiz content), then
    /// re-seeds bundled content (quiz bank + starter decks) and a fresh
    /// profile. The auth session is not touched; the UI requires sign-out
    /// first.
    static func eraseAllLocalData(context: ModelContext, bank: QuestionBank, weeklyXP: WeeklyXPStore = WeeklyXPStore()) throws {
        try deleteAll(FlashcardDeck.self, context: context)
        try deleteAll(Flashcard.self, context: context)
        try deleteAll(StudyProgressSnapshot.self, context: context)
        try deleteAll(DailyActivity.self, context: context)
        try deleteAll(BadgeAward.self, context: context)
        try deleteQuizProgress(context: context)
        try deleteAll(UserProfile.self, context: context)
        try deleteAll(Question.self, context: context)
        try deleteAll(Topic.self, context: context)
        try context.save()
        weeklyXP.reset()

        try DataSeeder.seed(context: context, bank: bank)
        try StarterDeckLoader.seed(context: context)
        Logger.settings.notice("All local data erased by user")
    }

    private static func deleteQuizProgress(context: ModelContext) throws {
        try deleteAll(QuestionProgress.self, context: context)
        try deleteAll(TopicProgress.self, context: context)
        try deleteAll(QuizAnswerRecord.self, context: context)
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }
}
