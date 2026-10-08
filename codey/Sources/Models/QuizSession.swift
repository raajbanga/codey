import Foundation
import SwiftData
import os

@Observable
final class QuizSession {
    static let baseXP = 10
    static let streakBonusPerLevel = 5

    var answerStreak: Int = 0
    var bestAnswerStreak: Int = 0
    var correctCount: Int = 0
    let totalQuestions: Int
    var sessionXPEarned: Int = 0

    init(totalQuestions: Int) {
        self.totalQuestions = totalQuestions
    }

    static func xpForCorrectAnswer(streakAfterIncrement: Int) -> Int {
        baseXP + (streakAfterIncrement - 1) * streakBonusPerLevel
    }

    @discardableResult
    func recordAnswer(correct: Bool, profile: UserProfile, context: ModelContext) -> Int {
        if correct {
            answerStreak += 1
            bestAnswerStreak = max(bestAnswerStreak, answerStreak)
            correctCount += 1

            let xpAwarded = Self.xpForCorrectAnswer(streakAfterIncrement: answerStreak)
            profile.totalXP += xpAwarded
            sessionXPEarned += xpAwarded
            do {
                try context.save()
            } catch {
                Logger.quiz.error("Saving XP failed: \(String(describing: error))")
            }
            return xpAwarded
        } else {
            answerStreak = 0
            return 0
        }
    }
}
