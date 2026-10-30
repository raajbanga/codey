import Foundation
import SwiftData
import os

/// Boot fails rather than seeding a truncated question bank.
enum DataSeederError: Error, LocalizedError {
    case insufficientTopics(found: Int, expected: Int)

    var errorDescription: String? {
        switch self {
        case .insufficientTopics(let found, let expected):
            return "Question bank loaded \(found) topics; expected \(expected)"
        }
    }
}

/// Puts bundled content into the store WITHOUT touching user data (B2).
///
/// Bundled rows (topics, questions; starter decks from Stage 4) are upserted
/// by stable id: inserted if missing, updated if the text changed, deleted
/// only if their id was removed from the bundle. The profile, progress, user
/// decks, and (later) the sync queue are never modified here. Safe to run on
/// every launch.
enum DataSeeder {
    struct Report: Equatable {
        var inserted = 0
        var updated = 0
        var deleted = 0
    }

    /// UserDefaults key the old destructive seeder used. Removed on seed.
    private static let legacySeedVersionKey = "codey.seedVersion"

    /// Boot-time entry point: upsert bundled content, make sure a profile
    /// exists, save.
    @discardableResult
    static func seed(context: ModelContext, bank: QuestionBank) throws -> Report {
        // A truncated bundle must not be read as "these topics were removed".
        guard bank.topics.count >= QuestionBankLoader.expectedTopicCount else {
            throw DataSeederError.insufficientTopics(
                found: bank.topics.count,
                expected: QuestionBankLoader.expectedTopicCount
            )
        }

        let report = try upsertBundledContent(bank, context: context)
        ensureProfile(context: context)
        if context.hasChanges {
            try context.save()
        }
        UserDefaults.standard.removeObject(forKey: legacySeedVersionKey)
        Logger.seeding.info(
            "Seeded bundled content: +\(report.inserted) ~\(report.updated) -\(report.deleted)"
        )
        return report
    }

    /// Upserts topics and questions by id. Does not save.
    static func upsertBundledContent(_ bank: QuestionBank, context: ModelContext) throws -> Report {
        var report = Report()

        var topics = try context.fetch(FetchDescriptor<Topic>()).keyed(by: \.id)
        for seed in bank.topics {
            if let topic = topics[seed.id] {
                var changed = false
                changed = assign(topic, \.title, seed.title) || changed
                changed = assign(topic, \.summary, seed.summary) || changed
                changed = assign(topic, \.iconName, seed.iconName) || changed
                if changed { report.updated += 1 }
            } else {
                let topic = Topic(id: seed.id, title: seed.title, summary: seed.summary, iconName: seed.iconName)
                context.insert(topic)
                topics[seed.id] = topic
                report.inserted += 1
            }
        }

        let questions = try context.fetch(FetchDescriptor<Question>()).keyed(by: \.id)
        for seed in bank.questions {
            guard let topic = topics[seed.topicId] else { continue }
            if let question = questions[seed.id] {
                var changed = false
                changed = assign(question, \.prompt, seed.prompt) || changed
                changed = assign(question, \.options, seed.options) || changed
                changed = assign(question, \.correctOptionIndex, seed.correctOptionIndex) || changed
                changed = assign(question, \.explanation, seed.explanation) || changed
                changed = assign(question, \.difficulty, seed.difficulty) || changed
                if question.topic?.id != topic.id {
                    question.topic = topic
                    changed = true
                }
                if changed { report.updated += 1 }
            } else {
                let question = Question(
                    id: seed.id,
                    prompt: seed.prompt,
                    options: seed.options,
                    correctOptionIndex: seed.correctOptionIndex,
                    explanation: seed.explanation,
                    difficulty: seed.difficulty
                )
                context.insert(question)
                question.topic = topic
                report.inserted += 1
            }
        }

        let seededQuestionIds = Set(bank.questions.map(\.id))
        for (id, question) in questions where !seededQuestionIds.contains(id) {
            context.delete(question)
            report.deleted += 1
        }
        let seededTopicIds = Set(bank.topics.map(\.id))
        for (id, topic) in topics where !seededTopicIds.contains(id) {
            context.delete(topic)
            report.deleted += 1
        }

        return report
    }

    /// Returns the single local profile, creating a fresh one (0 XP, B3) on
    /// first launch. Never modifies an existing profile.
    @discardableResult
    static func ensureProfile(context: ModelContext) -> UserProfile {
        if let existing: UserProfile = try? context.first() {
            return existing
        }
        let profile = UserProfile(username: UserProfile.defaultUsername)
        context.insert(profile)
        return profile
    }

    /// Writes `value` only if it differs, so an unchanged bundle leaves the
    /// store clean. Returns whether it wrote.
    private static func assign<Model, Value: Equatable>(
        _ model: Model,
        _ keyPath: ReferenceWritableKeyPath<Model, Value>,
        _ value: Value
    ) -> Bool {
        guard model[keyPath: keyPath] != value else { return false }
        model[keyPath: keyPath] = value
        return true
    }
}
