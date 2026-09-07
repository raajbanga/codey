import Foundation
import SwiftData
import os

enum DataSeederError: Error, LocalizedError {
    case insufficientTopics(found: Int, expected: Int)

    var errorDescription: String? {
        switch self {
        case .insufficientTopics(let found, let expected):
            return "Question bank loaded \(found) topics; expected \(expected)"
        }
    }
}

enum DataSeeder {
    /// Bump when the bundled question bank changes materially.
    static let seedVersion = 2
    private static let seedVersionKey = "codey.seedVersion"
    private static let logger = Logger(subsystem: "dev.tuist.codey", category: "DataSeeder")

    static func needsSeeding(context: ModelContext) -> Bool {
        let storedVersion = UserDefaults.standard.integer(forKey: seedVersionKey)
        let topicCount = fetchCount(Topic.self, context: context)
        return storedVersion != seedVersion || topicCount < QuestionBankLoader.expectedTopicCount
    }

    static func seedIfNeeded(context: ModelContext) {
        guard needsSeeding(context: context) else { return }
        do {
            let topics = try QuestionBankLoader.loadTopics()
            try seed(context: context, topics: topics)
        } catch {
            logger.error("Seed failed: \(error.localizedDescription)")
        }
    }

    static func resetAllData(context: ModelContext) {
        clearContent(context: context)
        UserDefaults.standard.removeObject(forKey: seedVersionKey)
        do {
            let topics = try QuestionBankLoader.loadTopics()
            try seed(context: context, topics: topics)
        } catch {
            logger.error("Reset failed: \(error.localizedDescription)")
        }
    }

    static func seed(context: ModelContext, topics: [Topic]) throws {
        clearContent(context: context)
        try insertSeedData(context: context, topics: topics)
    }

    static func insertSeedData(context: ModelContext, topics: [Topic]) throws {
        guard topics.count >= QuestionBankLoader.expectedTopicCount else {
            throw DataSeederError.insufficientTopics(
                found: topics.count,
                expected: QuestionBankLoader.expectedTopicCount
            )
        }

        context.insert(
            UserProfile(
                username: "Codey Learner",
                totalXP: 1250,
                currentStreak: 7,
                lastActiveDate: .now
            )
        )

        topics.forEach { topic in
            context.insert(topic)
            topic.questions.forEach { context.insert($0) }
        }

        try context.save()
        UserDefaults.standard.set(seedVersion, forKey: seedVersionKey)
        logger.info("Seeded \(topics.count) topics, \(topics.reduce(0) { $0 + $1.questions.count }) questions")
    }

    private static func clearContent(context: ModelContext) {
        deleteAll(UserProfile.self, context: context)
        deleteAll(Question.self, context: context)
        deleteAll(Topic.self, context: context)
        try? context.save()
    }

    private static func fetchCount<T: PersistentModel>(
        _ type: T.Type,
        context: ModelContext
    ) -> Int {
        (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
    }

    private static func deleteAll<T: PersistentModel>(
        _ type: T.Type,
        context: ModelContext
    ) {
        ((try? context.fetch(FetchDescriptor<T>())) ?? []).forEach { context.delete($0) }
    }
}
