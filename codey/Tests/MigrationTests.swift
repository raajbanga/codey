import Foundation
import SwiftData
import Testing
@testable import codey

/// B1: a schema bump must migrate the on-disk store, never wipe it.
@MainActor
struct MigrationTests {

    /// Writes a V1 store the way Sprint 2 builds did, then closes it.
    private func writeV1Store(at url: URL, schema: Schema) throws {
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        let context = ModelContext(container)
        let topic = CodeySchemaV1.Topic(id: "topic-x", title: "X", summary: "s", iconName: "star")
        context.insert(topic)
        let question = CodeySchemaV1.Question(
            id: "q-1", prompt: "p", options: ["a", "b", "c", "d"],
            correctOptionIndex: 1, explanation: "e", difficulty: .medium
        )
        context.insert(question)
        question.topic = topic
        context.insert(CodeySchemaV1.UserProfile(username: "Learner", totalXP: 730, currentStreak: 2))
        try context.save()
    }

    private func expectV1DataSurvives(at url: URL) throws {
        let container = TestSupport.retain(try ModelContainerFactory.make(url: url))
        let context = ModelContext(container)

        let profile = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(profile.totalXP == 730)
        #expect(profile.currentStreak == 2)
        let question = try #require(try context.fetch(FetchDescriptor<Question>()).first)
        #expect(question.topic?.id == "topic-x")
        #expect(question.difficulty == .medium)

        // V2 entities are usable in the migrated store.
        let deck = FlashcardDeck(title: "New", topicId: "topic-x", origin: .user)
        context.insert(deck)
        let card = try FlashcardFactory().createCard(
            prompt: "p", answer: "a", code: CodeSnippet(language: .python, source: "print(1)")
        )
        context.insert(card)
        card.deck = deck
        try context.save()
    }

    @Test func versionedV1StoreMigratesToCurrentWithoutDataLoss() throws {
        let url = try TestSupport.temporaryStoreURL()
        try writeV1Store(at: url, schema: Schema(versionedSchema: CodeySchemaV1.self))
        try expectV1DataSurvives(at: url)
    }

    /// Sprint 2 builds opened the store with a plain, unversioned Schema.
    @Test func unversionedSprint2StoreMigratesWithoutDataLoss() throws {
        let url = try TestSupport.temporaryStoreURL()
        try writeV1Store(
            at: url,
            schema: Schema([CodeySchemaV1.UserProfile.self, CodeySchemaV1.Topic.self, CodeySchemaV1.Question.self])
        )
        try expectV1DataSurvives(at: url)
    }

    /// Stage 5: a V2 store (decks + cards) opens as V3 with study progress.
    @Test func v2StoreMigratesToCurrentWithStudyProgress() throws {
        let url = try TestSupport.temporaryStoreURL()
        let deckId: UUID
        do {
            let schema = Schema(versionedSchema: CodeySchemaV2.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(container)
            let deck = try TestSupport.insertDeck(context, prompts: ["a", "b"])
            for _ in 0..<2 { deck.activeCards[0].updateMastery(rating: .easy) }
            deckId = deck.id
            try context.save()
        }

        let context = try TestSupport.context(storeURL: url)
        let deck = try #require(try context.fetch(FetchDescriptor<FlashcardDeck>(predicate: #Predicate { $0.id == deckId })).first)
        #expect(deck.cardCount == 2)
        #expect(deck.activeCards[0].masteryScore == 4)

        let vm = StudySessionViewModel(deck: deck, start: .fresh(tierFilter: nil), context: context)
        vm.toggleReveal()
        vm.rate(.good)
        #expect(try StudyProgressSnapshot.fetch(deckId: deckId, context: context) != nil)
        #expect(try context.fetchCount(FetchDescriptor<DailyActivity>()) == 1)
    }

    /// Stage 6: a V3 store opens as V4 and keeps study progress.
    @Test func v3StoreMigratesToCurrentWithQuizProgress() throws {
        let url = try TestSupport.temporaryStoreURL()
        let deckId: UUID
        do {
            let schema = Schema(versionedSchema: CodeySchemaV3.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(container)
            let deck = try TestSupport.insertDeck(context, prompts: ["a", "b"])
            deckId = deck.id
            let snapshot = StudyProgressSnapshot(deckId: deck.id)
            snapshot.cardIDs = deck.activeCards.map(\.id)
            snapshot.position = 1
            context.insert(snapshot)
            try context.save()
        }

        let context = try TestSupport.context(storeURL: url)
        #expect(try StudyProgressSnapshot.fetch(deckId: deckId, context: context)?.position == 1)
        let topic = try TestSupport.insertTopic(context, easy: 1, medium: 0, hard: 0)
        _ = try QuizProgressStore(context: context).recordAnswer(
            question: try #require(topic.questions.first), correct: true, level: 1, at: .now
        )
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<QuestionProgress>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<QuizAnswerRecord>()) == 1)
    }

    /// Stage 7: a V4 store opens as V5; the profile keeps its XP and gets
    /// an empty pin list.
    @Test func v4StoreMigratesToCurrentWithPinnedTopics() throws {
        let url = try TestSupport.temporaryStoreURL()
        do {
            let schema = Schema(versionedSchema: CodeySchemaV4.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(container)
            context.insert(CodeySchemaV1.UserProfile(username: "Learner", totalXP: 1_234))
            context.insert(QuizAnswerRecord(questionId: "q", topicId: "t", correct: true, answeredAt: .now))
            try context.save()
        }

        let context = try TestSupport.context(storeURL: url)
        let profile = try #require(try context.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(profile.totalXP == 1_234)
        #expect(profile.pinnedTopicIds.isEmpty)
        profile.pinnedTopicIds = ["topic-databases"]
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<QuizAnswerRecord>()) == 1)
    }

    @Test func decksPersistAcrossReopen() throws {
        let url = try TestSupport.temporaryStoreURL()
        let deckId: UUID
        do {
            let context = try TestSupport.context(storeURL: url)
            let deck = try TestSupport.insertDeck(context, prompts: ["a"])
            let card = try FlashcardFactory().createCard(
                prompt: "b", answer: "B",
                code: CodeSnippet(language: .cpp, source: "int main() {}"),
                difficulty: .hard, sortIndex: 1
            )
            context.insert(card)
            card.deck = deck
            deckId = deck.id
            try context.save()
        }

        let context = try TestSupport.context(storeURL: url)
        let deck = try #require(try context.fetch(FetchDescriptor<FlashcardDeck>(predicate: #Predicate { $0.id == deckId })).first)
        #expect(deck.cardCount == 2)
        let card = try #require(deck.activeCards.last)
        #expect(card.codeSnippet == CodeSnippet(language: .cpp, source: "int main() {}"))
        #expect(card.difficulty == .hard)
        #expect(deck.activeCards.first?.codeSnippet == nil)
    }

    @Test func destroyStoreRemovesFiles() throws {
        let url = try TestSupport.temporaryStoreURL()
        do {
            let context = try TestSupport.context(storeURL: url)
            context.insert(UserProfile(username: "x"))
            try context.save()
        }
        #expect(FileManager.default.fileExists(atPath: url.path))

        try ModelContainerFactory.destroyStore(at: url)

        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(!FileManager.default.fileExists(atPath: url.path + "-wal"))
    }
}

/// NFR-04: the on-disk store is file-protected (O6: completeUnlessOpen).
@MainActor
struct StoreFileProtectionTests {
    @Test func storeFolderAndFilesAreProtected() throws {
        let url = try TestSupport.temporaryStoreURL()
        let context = try TestSupport.context(storeURL: url)
        context.insert(UserProfile(username: "p"))
        try context.save()
        #expect(ModelContainerFactory.fileProtection == .completeUnlessOpen)

        // Setting the class succeeds for the folder, the store, and its WAL.
        let protected = ModelContainerFactory.applyFileProtection(storeURL: url)
        #expect(protected.contains(url.deletingLastPathComponent().path))
        #expect(protected.contains(url.path))

        #if targetEnvironment(simulator)
        // The Simulator has no Data Protection and reports nil; a device run
        // checks the attribute itself.
        #else
        for path in protected {
            let protection = try FileManager.default.attributesOfItem(atPath: path)[.protectionKey] as? FileProtectionType
            #expect(protection == ModelContainerFactory.fileProtection, "\(path)")
        }
        #endif
    }
}
