/// One topic's quiz standing: tier locks, accuracy over the last answers
/// (FR-36), and how many questions are retired. Shown on Play's tiles.
struct QuizTopicStats {
    let topic: Topic
    let tiers: [TierAvailability]
    let accuracy: Double?
    let retired: Int
    let total: Int
}
