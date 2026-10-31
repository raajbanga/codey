/// Tier-gating and quiz thresholds (FR-19, FR-23–28). One place, because the
/// doc says they'll be calibrated in Sprint 3.
struct GatingConfig: Equatable {
    /// Medium unlocks once this fraction of Easy is retired.
    var mediumUnlockFraction = 0.70
    /// Hard unlocks once this fraction of Medium is retired...
    var hardUnlockFraction = 0.70
    /// ...and the learner has reached this level.
    var hardMinimumLevel = 3

    /// FR-23/24: a quiz question retires after this many correct in a row.
    var retireAfterConsecutiveCorrect = 3
    /// FR-28: a retired question returns for review after this many days.
    var reviewAfterDays = 7
    /// FR-19: questions per quiz (fewer if the pool is smaller).
    var quizSize = 10
    /// FR-27: share of a mixed quiz drawn from the highest unlocked tier.
    var highestTierShare = 0.70
    /// FR-36: accuracy is over this many most recent answers per topic.
    var accuracyWindow = 50
    /// Answer history kept per topic.
    var answerHistoryCap = 200
    /// FR-32: quiz answers + card ratings per day that meet the daily goal
    /// (and count toward the streak, FR-33).
    var dailyGoal = 20

    static let standard = GatingConfig()
}
