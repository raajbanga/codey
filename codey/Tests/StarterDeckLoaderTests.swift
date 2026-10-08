import Foundation
import SwiftData
import Testing
@testable import codey

@MainActor
struct StarterDeckLoaderTests {

    /// A store with the quiz bank's topics (starter decks need known topics).
    private func seededContext() throws -> ModelContext {
        let context = try TestSupport.inMemoryContext()
        try DataSeeder.seed(context: context, bank: QuestionBankLoader.loadBank())
        return context
    }

    private func starterDecks(_ context: ModelContext) throws -> [FlashcardDeck] {
        try context.fetch(FetchDescriptor<FlashcardDeck>()).filter { $0.origin == .starter }
    }

    // MARK: Content (12 decks, ≥12 cards, all tiers, code coverage)

    @Test func bundleDecodesWithExpectedShape() throws {
        let file = try StarterDeckLoader.loadBundle()
        #expect(file.schemaVersion == 1)
        #expect(file.decks.count == StarterDeckLoader.expectedDeckCount)
        let topics = Set(try QuestionBankLoader.loadBank().topics.map(\.id))
        #expect(Set(file.decks.map(\.topicId)) == topics, "every topic has a starter deck")
    }

    @Test func everyDeckHasEnoughCardsInEveryTier() throws {
        for deck in try StarterDeckLoader.loadBundle().decks {
            #expect(deck.cards.count >= 12, "\(deck.starterKey)")
            for tier in Difficulty.allCases {
                #expect(deck.cards.filter { $0.difficulty == tier }.count >= 4, "\(deck.starterKey) \(tier)")
            }
            #expect(deck.cards.filter { $0.code != nil }.count >= 4, "\(deck.starterKey) code cards")
        }
    }

    @Test func everyLanguageAppearsAtLeastTwice() throws {
        let languages = try StarterDeckLoader.loadBundle().decks.flatMap(\.cards).compactMap(\.code?.language)
        for language in CodeLanguage.allCases {
            #expect(languages.filter { $0 == language.rawValue }.count >= 2, "\(language)")
        }
    }

    @Test func everyCardPassesTheValidator() throws {
        let validator = ModelValidator()
        for card in try StarterDeckLoader.loadBundle().decks.flatMap(\.cards) {
            let payload = card.payload(sortIndex: 0)
            let errors = validator.validateCard(ModelValidator.CardFields(
                id: payload.id ?? UUID(),
                prompt: payload.prompt,
                answer: payload.answer,
                codeLanguage: payload.codeLanguage,
                codeSource: payload.codeSource
            ))
            #expect(errors.isEmpty, "\(card.id): \(errors)")
            #expect(throws: Never.self) { _ = try FlashcardFactory().createCard(from: payload) }
        }
    }

    @Test func stableIDsAreDeterministic() {
        #expect(StableID.uuid("sc-ds-001") == StableID.uuid("sc-ds-001"))
        #expect(StableID.uuid("sc-ds-001") != StableID.uuid("sc-ds-002"))
        #expect(StableID.uuid("starter-ds") != StableID.uuid("starter-ds", namespace: "other"))
    }

    // MARK: Loading

    @Test func freshInstallGetsEveryStarterDeck() throws {
        let context = try seededContext()

        let report = try StarterDeckLoader.seed(context: context)

        let decks = try starterDecks(context)
        #expect(decks.count == StarterDeckLoader.expectedDeckCount)
        #expect(report.inserted == decks.count + decks.reduce(0) { $0 + $1.cardCount })
        for deck in decks {
            #expect(deck.id == StableID.uuid(deck.starterKey ?? ""))
            #expect(!deck.isEditable)
            #expect(deck.syncState == .locallyPersisted)
            #expect(deck.activeCards.allSatisfy { $0.difficulty != nil })
            #expect(deck.activeCards.map(\.sortIndex) == Array(0..<deck.cardCount))
        }
        let dsCard = try #require(decks.first { $0.starterKey == "starter-ds" }?.activeCards.first { $0.id == StableID.uuid("sc-ds-004") })
        #expect(dsCard.codeSnippet?.language == .swift)
    }

    @Test func reseedingIsIdempotent() throws {
        let context = try seededContext()
        try StarterDeckLoader.seed(context: context)
        let cardCount = try context.fetchCount(FetchDescriptor<Flashcard>())

        let second = try StarterDeckLoader.seed(context: context)

        #expect(second == DataSeeder.Report())
        #expect(try starterDecks(context).count == StarterDeckLoader.expectedDeckCount)
        #expect(try context.fetchCount(FetchDescriptor<Flashcard>()) == cardCount)
    }

    @Test func contentUpdateKeepsMasteryRetirementAndHidden() throws {
        let context = try seededContext()
        let file = try StarterDeckLoader.loadBundle()
        try StarterDeckLoader.seed(context: context, file: file)

        let deck = try #require(try starterDecks(context).first { $0.starterKey == "starter-ds" })
        deck.isHidden = true
        let card = try #require(deck.activeCards.first)
        for _ in 0..<3 { card.updateMastery(rating: .easy) }
        let retiredAt = try #require(card.retiredAt)
        try context.save()

        // Reword the first card and rename the deck.
        var decks = file.decks
        var cards = decks[0].cards
        let old = cards[0]
        cards[0] = StarterCardSeed(id: old.id, prompt: old.prompt + " (reworded)", answer: old.answer, difficulty: old.difficulty, code: old.code)
        decks[0] = StarterDeckSeed(starterKey: decks[0].starterKey, topicId: decks[0].topicId, title: "Renamed", cards: cards)
        let report = try StarterDeckLoader.seed(context: context, file: StarterDeckFile(schemaVersion: 1, decks: decks))

        #expect(report == DataSeeder.Report(inserted: 0, updated: 2, deleted: 0))
        #expect(deck.title == "Renamed")
        #expect(deck.isHidden)
        #expect(card.prompt.hasSuffix("(reworded)"))
        #expect(card.masteryScore == 5)
        #expect(card.retiredAt == retiredAt)
    }

    @Test func removedCardsAndDecksAreDeletedButUserDecksAreNot() throws {
        let context = try seededContext()
        let file = try StarterDeckLoader.loadBundle()
        try StarterDeckLoader.seed(context: context, file: file)
        let userDeck = try TestSupport.insertDeck(context, title: "Mine", prompts: ["q"])
        try context.save()

        var decks = file.decks
        let droppedCard = decks[0].cards.last!
        decks[0] = StarterDeckSeed(starterKey: decks[0].starterKey, topicId: decks[0].topicId, title: decks[0].title, cards: Array(decks[0].cards.dropLast()))
        // Keep ≥ expectedDeckCount decks so the truncation guard doesn't trip:
        // replace the last deck with a new one.
        let droppedDeck = decks.removeLast()
        decks.append(StarterDeckSeed(starterKey: "starter-new", topicId: droppedDeck.topicId, title: "New", cards: [droppedDeck.cards[0]]
            .map { StarterCardSeed(id: "sc-new-001", prompt: $0.prompt, answer: $0.answer, difficulty: $0.difficulty, code: $0.code) }))

        try StarterDeckLoader.seed(context: context, file: StarterDeckFile(schemaVersion: 1, decks: decks))

        let keys = Set(try starterDecks(context).compactMap(\.starterKey))
        #expect(keys == Set(file.decks.dropLast().map(\.starterKey)).union(["starter-new"]))
        let droppedID = StableID.uuid(droppedCard.id)
        #expect(try context.fetch(FetchDescriptor<Flashcard>()).allSatisfy { $0.id != droppedID })
        #expect(userDeck.cardCount == 1)
        #expect(try context.fetch(FetchDescriptor<FlashcardDeck>()).contains { $0.id == userDeck.id })
    }

    @Test func truncatedBundleIsIgnored() throws {
        let context = try seededContext()
        let file = try StarterDeckLoader.loadBundle()
        try StarterDeckLoader.seed(context: context, file: file)

        let report = try StarterDeckLoader.seed(context: context, file: StarterDeckFile(schemaVersion: 1, decks: [file.decks[0]]))

        #expect(report == DataSeeder.Report())
        #expect(try starterDecks(context).count == StarterDeckLoader.expectedDeckCount)
    }
}
