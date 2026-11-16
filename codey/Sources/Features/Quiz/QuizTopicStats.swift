/// One topic's quiz standing: tier locks, accuracy over the last answers
/// (FR-36), and how many questions are retired. Shown on Play's tiles.
struct QuizTopicStats {
    let topic: Topic
    let tiers: [TierAvailability]
    let accuracy: Double?
    let retired: Int
    let total: Int
}

extension QuizTopicStats {
    /// Tier locks, accuracy over the last answers (FR-36), and retired
    /// count, from rows that may cover every topic.
    @MainActor init(topic: Topic, progressRows: [QuestionProgress], topicProgress: [TopicProgress], records: [QuizAnswerRecord], xp: Int) {
        let progress = progressRows.filter { $0.topicId == topic.id }.keyed(by: \.questionId)
        let sticky = topicProgress.first { $0.topicId == topic.id }?.unlockedTiers ?? []
        self.init(
            topic: topic,
            tiers: QuizProgressStore.availability(questions: topic.questions, progress: progress, sticky: sticky, xp: xp),
            accuracy: QuizProgressStore.accuracy(
                of: records.filter { $0.topicId == topic.id },
                window: GatingConfig.standard.accuracyWindow
            ),
            retired: topic.questions.filter { progress[$0.id]?.isRetired == true }.count,
            total: topic.questions.count
        )
    }
}
