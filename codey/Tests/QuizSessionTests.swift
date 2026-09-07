import SwiftData
import Testing
@testable import codey

struct QuizSessionTests {

    @Test func xpForThreeConsecutiveCorrectAnswers() {
        #expect(QuizSession.xpForCorrectAnswer(streakAfterIncrement: 1) == 10)
        #expect(QuizSession.xpForCorrectAnswer(streakAfterIncrement: 2) == 15)
        #expect(QuizSession.xpForCorrectAnswer(streakAfterIncrement: 3) == 20)
    }

    @Test @MainActor func streakResetsOnWrongAnswer() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProfile.self, Topic.self, Question.self,
            configurations: config
        )
        let context = container.mainContext

        let profile = UserProfile(username: "Test", totalXP: 100, currentStreak: 5)
        context.insert(profile)

        let session = QuizSession(totalQuestions: 5)

        let xp1 = session.recordAnswer(correct: true, profile: profile, context: context)
        let xp2 = session.recordAnswer(correct: true, profile: profile, context: context)
        let xp3 = session.recordAnswer(correct: true, profile: profile, context: context)

        #expect(xp1 == 10)
        #expect(xp2 == 15)
        #expect(xp3 == 20)
        #expect(session.answerStreak == 3)
        #expect(session.bestAnswerStreak == 3)
        #expect(profile.totalXP == 145)

        let xpWrong = session.recordAnswer(correct: false, profile: profile, context: context)
        #expect(xpWrong == 0)
        #expect(session.answerStreak == 0)
        #expect(profile.totalXP == 145)
        #expect(profile.currentStreak == 5)

        let xpAfterReset = session.recordAnswer(correct: true, profile: profile, context: context)
        #expect(xpAfterReset == 10)
        #expect(session.answerStreak == 1)
        #expect(profile.totalXP == 155)
    }

    @Test @MainActor func bestAnswerStreakTracksPeak() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProfile.self, Topic.self, Question.self,
            configurations: config
        )
        let context = container.mainContext

        let profile = UserProfile(username: "Test", totalXP: 0)
        context.insert(profile)

        let session = QuizSession(totalQuestions: 6)

        _ = session.recordAnswer(correct: true, profile: profile, context: context)
        _ = session.recordAnswer(correct: true, profile: profile, context: context)
        _ = session.recordAnswer(correct: false, profile: profile, context: context)
        _ = session.recordAnswer(correct: true, profile: profile, context: context)

        #expect(session.bestAnswerStreak == 2)
    }
}
