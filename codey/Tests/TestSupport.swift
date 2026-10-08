import Foundation
import SwiftData
@testable import codey

enum TestSupport {
    @MainActor
    static func inMemoryContext() throws -> ModelContext {
        try ModelContainerFactory.make(inMemory: true).mainContext
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
}
