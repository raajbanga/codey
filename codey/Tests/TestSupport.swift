import Foundation
import SwiftData
@testable import codey

enum TestSupport {
    /// A ModelContext does NOT retain its ModelContainer. If the container is
    /// freed, the next fetch/save traps inside SwiftData (EXC_BREAKPOINT), which
    /// is the "codey closed unexpectedly" crash. Tests keep every container
    /// here for the life of the process.
    @MainActor private static var liveContainers: [ModelContainer] = []

    @MainActor
    @discardableResult
    static func retain(_ container: ModelContainer) -> ModelContainer {
        liveContainers.append(container)
        return container
    }

    @MainActor
    static func inMemoryContext() throws -> ModelContext {
        retain(try ModelContainerFactory.make(inMemory: true)).mainContext
    }

    /// A context on an on-disk store whose container stays alive.
    @MainActor
    static func context(storeURL url: URL) throws -> ModelContext {
        ModelContext(retain(try ModelContainerFactory.make(url: url)))
    }

    /// A unique on-disk store URL in a fresh temp directory.
    static func temporaryStoreURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "codey-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "Codey.store")
    }

    /// Inserts a user deck with one card per prompt.
    @discardableResult
    static func insertDeck(
        _ context: ModelContext,
        title: String = "My Deck",
        origin: DeckOrigin = .user,
        prompts: [String] = ["Q1"]
    ) throws -> FlashcardDeck {
        let deck = FlashcardDeck(title: title, topicId: "topic-data-structures", origin: origin)
        context.insert(deck)
        let factory = FlashcardFactory()
        for (index, prompt) in prompts.enumerated() {
            let card = try factory.createCard(prompt: prompt, answer: "A", sortIndex: index)
            context.insert(card)
            card.deck = deck
        }
        return deck
    }

    /// Inserts a deck with one card per tier entry (nil = untagged), in order.
    @discardableResult
    static func insertTieredDeck(
        _ context: ModelContext,
        title: String = "Tiered",
        origin: DeckOrigin,
        tiers: [Difficulty?]
    ) throws -> FlashcardDeck {
        let deck = FlashcardDeck(title: title, topicId: "topic-data-structures", origin: origin, syncState: .locallyPersisted)
        context.insert(deck)
        let factory = FlashcardFactory()
        for (index, tier) in tiers.enumerated() {
            let card = try factory.createCard(prompt: "Q\(index)", answer: "A\(index)", difficulty: tier, sortIndex: index)
            context.insert(card)
            card.deck = deck
        }
        try context.save()
        return deck
    }

    /// Inserts a quiz topic with the given number of questions per tier.
    /// Every question's correct answer is option 0. Ids: "<topic>-e1", "-m1", "-h1"…
    @discardableResult
    static func insertTopic(
        _ context: ModelContext,
        id: String = "topic-test",
        easy: Int,
        medium: Int,
        hard: Int
    ) throws -> Topic {
        let topic = Topic(id: id, title: "Test Topic", summary: "s", iconName: "star")
        context.insert(topic)
        for (tier, count, tag) in [(Difficulty.easy, easy, "e"), (.medium, medium, "m"), (.hard, hard, "h")] {
            for n in 0..<count {
                let question = Question(
                    id: "\(id)-\(tag)\(n + 1)", prompt: "Q", options: ["right", "w1", "w2", "w3"],
                    correctOptionIndex: 0, explanation: "e", difficulty: tier
                )
                context.insert(question)
                question.topic = topic
            }
        }
        try context.save()
        return topic
    }
}
