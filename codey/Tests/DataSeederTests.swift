import Foundation
import SwiftData
import Testing
@testable import codey

@MainActor
struct DataSeederTests {

    private func counts(_ context: ModelContext) throws -> (topics: Int, questions: Int, profiles: Int) {
        (
            try context.fetchCount(FetchDescriptor<Topic>()),
            try context.fetchCount(FetchDescriptor<Question>()),
            try context.fetchCount(FetchDescriptor<UserProfile>())
        )
    }

    @Test func seedsEmptyStoreWithFreshProfile() throws {
        let context = try TestSupport.inMemoryContext()

        DataSeeder.seedIfNeeded(context: context)

        let topics = try context.fetch(FetchDescriptor<Topic>())
        #expect(topics.count == QuestionBankLoader.expectedTopicCount)
        #expect(topics.allSatisfy { !$0.questions.isEmpty })
        #expect(try context.fetchCount(FetchDescriptor<Question>()) == QuestionBankLoader.expectedQuestionCount)

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.username == "Codey Learner")
        #expect(profiles.first?.totalXP == 0)
        #expect(profiles.first?.currentStreak == 0)
    }

    @Test func reseedingIsIdempotent() throws {
        let context = try TestSupport.inMemoryContext()
        let bank = try QuestionBankLoader.loadBank()

        let first = try DataSeeder.seed(context: context, bank: bank)
        let before = try counts(context)
        let second = try DataSeeder.seed(context: context, bank: bank)

        #expect(first.inserted == bank.topics.count + bank.questions.count)
        #expect(second == DataSeeder.Report())
        #expect(try counts(context) == before)
        #expect(!context.hasChanges)
    }

    @Test func reseedingKeepsProfileAndUserDecks() throws {
        let context = try TestSupport.inMemoryContext()
        let bank = try QuestionBankLoader.loadBank()
        try DataSeeder.seed(context: context, bank: bank)

        let profile = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        profile.totalXP = 730
        profile.currentStreak = 4
        try TestSupport.insertDeck(context, prompts: ["a", "b"])
        try context.save()

        var changed = bank
        changed.questions[0] = QuestionSeed(
            id: bank.questions[0].id,
            topicId: bank.questions[0].topicId,
            prompt: "Reworded prompt",
            options: bank.questions[0].options,
            correctOptionIndex: bank.questions[0].correctOptionIndex,
            explanation: bank.questions[0].explanation,
            difficulty: bank.questions[0].difficulty
        )
        try DataSeeder.seed(context: context, bank: changed)

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.totalXP == 730)
        #expect(profiles.first?.currentStreak == 4)
        #expect(try context.fetchCount(FetchDescriptor<FlashcardDeck>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Flashcard>()) == 2)
    }

    @Test func updatesChangedTextInPlace() throws {
        let context = try TestSupport.inMemoryContext()
        let bank = try QuestionBankLoader.loadBank()
        try DataSeeder.seed(context: context, bank: bank)

        let original = bank.questions[0]
        let otherTopic = try #require(bank.topics.first { $0.id != original.topicId })
        var changed = bank
        changed.questions[0] = QuestionSeed(
            id: original.id,
            topicId: otherTopic.id,
            prompt: "New prompt",
            options: ["w", "x", "y", "z"],
            correctOptionIndex: 3,
            explanation: "New explanation",
            difficulty: .hard
        )
        changed.topics[0] = TopicSeed(
            id: bank.topics[0].id,
            title: "Renamed",
            summary: bank.topics[0].summary,
            iconName: bank.topics[0].iconName
        )

        let report = try DataSeeder.seed(context: context, bank: changed)

        #expect(report == DataSeeder.Report(inserted: 0, updated: 2, deleted: 0))
        let id = original.id
        let question = try #require(try context.fetch(FetchDescriptor<Question>(predicate: #Predicate { $0.id == id })).first)
        #expect(question.prompt == "New prompt")
        #expect(question.options == ["w", "x", "y", "z"])
        #expect(question.correctOptionIndex == 3)
        #expect(question.explanation == "New explanation")
        #expect(question.difficulty == .hard)
        #expect(question.topic?.id == otherTopic.id)
        let topicId = bank.topics[0].id
        let topic = try #require(try context.fetch(FetchDescriptor<Topic>(predicate: #Predicate { $0.id == topicId })).first)
        #expect(topic.title == "Renamed")
        #expect(try context.fetchCount(FetchDescriptor<Question>()) == bank.questions.count)
    }

    @Test func deletesOnlyRowsRemovedFromBundle() throws {
        let context = try TestSupport.inMemoryContext()
        let bank = try QuestionBankLoader.loadBank()
        try DataSeeder.seed(context: context, bank: bank)

        var trimmed = bank
        let removed = trimmed.questions.removeLast()
        let report = try DataSeeder.seed(context: context, bank: trimmed)

        #expect(report == DataSeeder.Report(inserted: 0, updated: 0, deleted: 1))
        let ids = Set(try context.fetch(FetchDescriptor<Question>()).map(\.id))
        #expect(ids.count == bank.questions.count - 1)
        #expect(!ids.contains(removed.id))
    }

    @Test func truncatedBundleThrowsWithoutDeleting() throws {
        let context = try TestSupport.inMemoryContext()
        let bank = try QuestionBankLoader.loadBank()
        try DataSeeder.seed(context: context, bank: bank)

        let broken = QuestionBank(topics: Array(bank.topics.prefix(1)), questions: [])
        #expect(throws: DataSeederError.self) {
            try DataSeeder.seed(context: context, bank: broken)
        }
        #expect(try context.fetchCount(FetchDescriptor<Question>()) == bank.questions.count)
    }

    @Test func ensureProfileNeverReplacesExisting() throws {
        let context = try TestSupport.inMemoryContext()
        context.insert(UserProfile(username: "Raaj", totalXP: 1250, currentStreak: 7))
        try context.save()

        let profile = DataSeeder.ensureProfile(context: context)

        #expect(profile.username == "Raaj")
        #expect(profile.totalXP == 1250)
        #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
    }
}

@MainActor
struct LocalDataResetTests {

    @Test func resetProgressZeroesXPAndMasteryButKeepsDecks() throws {
        let context = try TestSupport.inMemoryContext()
        try DataSeeder.seed(context: context, bank: QuestionBankLoader.loadBank())
        let profile = DataSeeder.ensureProfile(context: context)
        profile.totalXP = 900
        profile.currentStreak = 3
        profile.lastActiveDate = .now
        let deck = try TestSupport.insertDeck(context, prompts: ["a", "b"])
        deck.activeCards.forEach { $0.updateMastery(rating: .easy) }
        try context.save()

        try LocalDataReset.resetProgress(context: context)

        #expect(profile.totalXP == 0)
        #expect(profile.currentStreak == 0)
        #expect(profile.lastActiveDate == nil)
        #expect(deck.activeCards.count == 2)
        #expect(deck.activeCards.allSatisfy { $0.masteryScore == 0 && $0.lastReviewedAt == nil })
        #expect(try context.fetchCount(FetchDescriptor<Question>()) == QuestionBankLoader.expectedQuestionCount)
    }

    @Test func eraseAllRemovesUserDataAndReseeds() throws {
        let context = try TestSupport.inMemoryContext()
        let bank = try QuestionBankLoader.loadBank()
        try DataSeeder.seed(context: context, bank: bank)
        DataSeeder.ensureProfile(context: context).totalXP = 900
        try TestSupport.insertDeck(context, prompts: ["a", "b"])
        try context.save()

        try LocalDataReset.eraseAllLocalData(context: context, bank: bank)

        #expect(try context.fetchCount(FetchDescriptor<FlashcardDeck>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Flashcard>()) == 0)
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.totalXP == 0)
        #expect(try context.fetchCount(FetchDescriptor<Topic>()) == bank.topics.count)
        #expect(try context.fetchCount(FetchDescriptor<Question>()) == bank.questions.count)
    }
}
