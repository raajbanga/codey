/// Tier-gating thresholds (FR-25/26). One place, because the doc says
/// they'll be calibrated in Sprint 3. Stage 6 adds the quiz-side values.
struct GatingConfig: Equatable {
    /// Medium unlocks once this fraction of Easy is retired.
    var mediumUnlockFraction = 0.70
    /// Hard unlocks once this fraction of Medium is retired...
    var hardUnlockFraction = 0.70
    /// ...and the learner has reached this level.
    var hardMinimumLevel = 3

    static let standard = GatingConfig()
}
