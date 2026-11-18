import Foundation
import SwiftData

/// Every XP source beyond a correct quiz answer (S41, the game layer), and
/// the one place XP is added, so the level, the leaderboard's weekly XP,
/// and the badges all see the same amount. Rewards that could be farmed
/// pay once:
///
///     card moves up a mastery step     +5   (a re-rating that doesn't
///                                            raise the score pays 0)
///     exercise solved, per blank       +10  first solve only
///     daily goal met                   +50  once per local day
///     weekly challenge complete        +100 once per UTC week
enum XPRewards {
    static let cardMovedUp = 5
    static let exerciseBlank = 10
    static let dailyGoalBonus = 50
    static let weeklyChallengeBonus = 100

    /// A bonus paid this call, for a toast.
    enum Bonus: Equatable {
        case dailyGoal, weeklyChallenge

        var amount: Int {
            switch self {
            case .dailyGoal: XPRewards.dailyGoalBonus
            case .weeklyChallenge: XPRewards.weeklyChallengeBonus
            }
        }

        var title: String {
            switch self {
            case .dailyGoal: "Daily goal met"
            case .weeklyChallenge: "Weekly challenge done"
            }
        }
    }

    /// Adds XP to the total and to this week's leaderboard XP (FR-42).
    static func grant(_ amount: Int, to profile: UserProfile, weeklyXP: WeeklyXPStore, now: Date) {
        guard amount > 0 else { return }
        profile.totalXP += amount
        weeklyXP.add(amount, now: now)
    }

    /// XP for a rating that moved a card from `previous` to `new`.
    static func forCard(previousScore previous: Int, newScore new: Int) -> Int {
        new > previous ? cardMovedUp : 0
    }

    /// Pays a fully solved exercise the first time only. Returns the XP paid.
    @discardableResult
    static func solveExercise(id: String, blanks: Int, profile: UserProfile, weeklyXP: WeeklyXPStore, now: Date) -> Int {
        guard !profile.solvedExerciseIds.contains(id) else { return 0 }
        profile.solvedExerciseIds.append(id)
        let amount = exerciseBlank * blanks
        grant(amount, to: profile, weeklyXP: weeklyXP, now: now)
        return amount
    }

    /// FR-69: an accepted coding challenge, by difficulty.
    static func challengeReward(_ difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: 20
        case .medium: 35
        case .hard: 50
        }
    }

    /// Pays an accepted challenge the first time only (ids start with ch-,
    /// so they share solvedExerciseIds without clashing). Returns the XP paid.
    @discardableResult
    static func solveChallenge(id: String, difficulty: Difficulty, profile: UserProfile, weeklyXP: WeeklyXPStore, now: Date) -> Int {
        guard !profile.solvedExerciseIds.contains(id) else { return 0 }
        profile.solvedExerciseIds.append(id)
        let amount = challengeReward(difficulty)
        grant(amount, to: profile, weeklyXP: weeklyXP, now: now)
        return amount
    }

    /// Pays the daily-goal and weekly-challenge bonuses that are met and not
    /// yet paid for this day / week. Call after anything that counts toward
    /// them (a quiz answer, a card rating). Returns the bonuses paid now.
    @discardableResult
    static func payQuestBonuses(
        context: ModelContext,
        profile: UserProfile,
        weeklyXP: WeeklyXPStore,
        now: Date,
        calendar: Calendar = .current
    ) throws -> [Bonus] {
        var paid: [Bonus] = []
        let day = DailyActivity.dayKey(for: now, calendar: calendar)
        if profile.goalBonusDay != day,
           (try StreakCalculator.dayTotals(for: [day], context: context)[day] ?? 0) >= GatingConfig.standard.dailyGoal {
            profile.goalBonusDay = day
            grant(Bonus.dailyGoal.amount, to: profile, weeklyXP: weeklyXP, now: now)
            paid.append(.dailyGoal)
        }
        let week = UTCWeek.key(for: now)
        if profile.challengeBonusWeek != week, try WeeklyChallenge.isComplete(context: context, now: now) {
            profile.challengeBonusWeek = week
            grant(Bonus.weeklyChallenge.amount, to: profile, weeklyXP: weeklyXP, now: now)
            paid.append(.weeklyChallenge)
        }
        return paid
    }
}

extension WeeklyChallenge {
    /// This week's challenge is done (15 correct in its topic since Monday
    /// 00:00 UTC). Shared by the badge and the XP bonus.
    static func isComplete(context: ModelContext, now: Date) throws -> Bool {
        var topics = FetchDescriptor<Topic>()
        topics.propertiesToFetch = [\.id]
        guard let topic = topicID(for: now, topicIDs: try context.fetch(topics).map(\.id)) else { return false }
        let start = UTCWeek.start(of: now)
        let correct = try context.fetchCount(FetchDescriptor<QuizAnswerRecord>(
            predicate: #Predicate { $0.topicId == topic && $0.correct == true && $0.answeredAt >= start }
        ))
        return correct >= goal
    }
}
