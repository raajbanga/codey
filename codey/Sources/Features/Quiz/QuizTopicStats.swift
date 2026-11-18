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
        // One pass over the questions (each read is a store fetch): the
        // tiers, retired and total all come from the same tallies.
        let tallies = QuizProgressStore.tallies(questions: topic.questions, progress: progress)
        self.init(
            topic: topic,
            tiers: QuizProgressStore.availability(tallies: tallies, sticky: sticky, xp: xp),
            accuracy: QuizProgressStore.accuracy(
                of: records.filter { $0.topicId == topic.id },
                window: GatingConfig.standard.accuracyWindow
            ),
            retired: tallies.values.reduce(0) { $0 + $1.retired },
            total: tallies.values.reduce(0) { $0 + $1.total }
        )
    }

    /// Every topic's stats, grouping the rows by topic once instead of
    /// filtering all of them for each tile (the Library's grid).
    @MainActor static func byTopic(_ topics: [Topic], progressRows: [QuestionProgress], topicProgress: [TopicProgress], records: [QuizAnswerRecord], xp: Int) -> [String: QuizTopicStats] {
        let progress = Dictionary(grouping: progressRows, by: \.topicId)
        let answers = Dictionary(grouping: records, by: \.topicId)
        return Dictionary(uniqueKeysWithValues: topics.map { topic in
            (topic.id, QuizTopicStats(topic: topic, progressRows: progress[topic.id] ?? [], topicProgress: topicProgress, records: answers[topic.id] ?? [], xp: xp))
        })
    }
}
