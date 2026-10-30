import Foundation
import SwiftData
import Testing
@testable import codey

/// Deck builder view model (UC-02): editing the draft, live validation, save
/// and delete through the DeckBackend.
@MainActor
struct DeckViewModelTests {
    private let topicIds: Set<String> = ["topic-data-structures", "topic-algorithms"]

    private func makeContext() throws -> ModelContext {
        try TestSupport.inMemoryContext()
    }

    private func makeVM(_ context: ModelContext, editing deck: FlashcardDeck? = nil) -> DeckViewModel {
        DeckViewModel(
            backend: BackendFacade.localOnly(context: context),
            knownTopicIds: topicIds,
            editing: deck,
            defaultTopicId: "topic-data-structures",
            liveValidationDelay: .zero
        )
    }

    private func fillValidDeck(_ vm: DeckViewModel) {
        vm.draft.title = "Swift Basics"
        vm.draft.cards[0].prompt = "What does `let` declare?"
        vm.draft.cards[0].answer = "A constant."
        let second = vm.addCard()
        let index = vm.draft.cards.firstIndex { $0.id == second }!
        vm.draft.cards[index].prompt = "What prints?"
        vm.draft.cards[index].answer = "0 1 2"
        vm.draft.cards[index].snippet = SnippetDraft(language: .python, source: "for i in range(3):\n\tprint(i)  ")
        vm.draft.cards[index].difficulty = .medium
    }

    private func decks(_ context: ModelContext) throws -> [FlashcardDeck] {
        try context.fetch(FetchDescriptor<FlashcardDeck>())
    }

    @Test func newDraftStartsWithOneEmptyCard() throws {
        let vm = makeVM(try makeContext())
        #expect(vm.draft.cards.count == 1)
        #expect(vm.draft.topicId == "topic-data-structures")
        #expect(!vm.isEditing)
        #expect(!vm.hasUnsavedChanges)
        #expect(vm.fieldErrors.isEmpty)
    }

    @Test func createValidDeckPersistsCardsThroughFactory() throws {
        let context = try makeContext()
        let vm = makeVM(context)
        fillValidDeck(vm)

        let deck = try #require(vm.save())

        #expect(vm.uiState == .savedSuccess)
        #expect(try decks(context).count == 1)
        #expect(deck.title == "Swift Basics")
        #expect(deck.origin == .user)
        #expect(deck.syncState == .locallyPersisted)
        #expect(deck.activeCards.map(\.prompt) == ["What does `let` declare?", "What prints?"])
        let coded = deck.activeCards[1]
        #expect(coded.codeSnippet == CodeSnippet(language: .python, source: "for i in range(3):\n    print(i)"), "normalized by the factory")
        #expect(coded.difficulty == .medium)
        #expect(coded.sortIndex == 1)
    }

    @Test func createDeckMatchesSequenceDiagramSignature() throws {
        let context = try makeContext()
        let vm = makeVM(context)
        let card = CardDraft(prompt: "Q", answer: "A")
        let deck = try #require(vm.createDeck(title: "T", topic: "topic-algorithms", cardData: [card]))
        #expect(deck.topicId == "topic-algorithms")
        #expect(deck.activeCards.first?.id == card.id)
    }

    @Test func invalidDeckShowsErrorsAndPersistsNothing() throws {
        let context = try makeContext()
        let vm = makeVM(context)
        vm.draft.title = "   "
        vm.draft.cards[0].answer = "A"
        let bad = vm.draft.cards[0].id

        #expect(vm.save() == nil)

        #expect(try decks(context).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<Flashcard>()) == 0)
        #expect(vm.error(for: .deckTitle) != nil)
        #expect(vm.error(for: .cardPrompt(bad)) != nil)
        #expect(vm.error(for: .cardAnswer(bad)) == nil)
        #expect(vm.firstInvalidCardID == bad)
        #expect(vm.errorCount(cardID: bad) == 1)
        #expect(vm.uiState == .failed("Fix the highlighted fields."))
    }

    @Test func noErrorsBeforeFirstSaveAttempt() async throws {
        let vm = makeVM(try makeContext())
        vm.draft.cards[0].prompt = String(repeating: "x", count: 600)
        try await Task.sleep(for: .milliseconds(20))
        #expect(vm.fieldErrors.isEmpty)
        #expect(!vm.hasAttemptedSave)
    }

    @Test func liveValidationAfterFailedSave() async throws {
        let vm = makeVM(try makeContext())
        #expect(vm.save() == nil)
        #expect(vm.error(for: .deckTitle) != nil)

        vm.draft.title = "Fixed"
        try await Task.sleep(for: .milliseconds(50))

        #expect(vm.error(for: .deckTitle) == nil)
        #expect(vm.uiState == .idle)
    }

    @Test func snippetErrorsAreKeyedToTheCard() throws {
        let vm = makeVM(try makeContext())
        fillValidDeck(vm)
        vm.toggleSnippet(cardID: vm.draft.cards[0].id)
        let id = vm.draft.cards[0].id

        #expect(vm.save() == nil)
        #expect(vm.error(for: .snippetSource(id)) != nil)
        #expect(FocusRequest.firstError(in: vm, cardID: id) == FocusRequest(cardID: id, field: .snippet))
    }

    @Test func editUpdatesAddsAndRemovesCards() throws {
        let context = try makeContext()
        let creator = makeVM(context)
        fillValidDeck(creator)
        let deck = try #require(creator.save())
        let originalUpdatedAt = deck.updatedAt
        let removedID = deck.activeCards[0].id

        let editor = makeVM(context, editing: deck)
        #expect(editor.isEditing)
        #expect(editor.draft.cards.count == 2)
        #expect(!editor.hasUnsavedChanges)
        editor.draft.title = "Swift Basics II"
        editor.deleteCard(cardID: removedID)
        editor.draft.cards[0].answer = "Zero, one, two"
        let added = editor.addCard()
        let addedIndex = editor.draft.cards.firstIndex { $0.id == added }!
        editor.draft.cards[addedIndex].prompt = "New?"
        editor.draft.cards[addedIndex].answer = "Yes"
        #expect(editor.hasUnsavedChanges)

        let saved = try #require(editor.save())

        #expect(saved.id == deck.id)
        #expect(try decks(context).count == 1)
        #expect(saved.title == "Swift Basics II")
        #expect(saved.activeCards.map(\.prompt) == ["What prints?", "New?"])
        #expect(saved.activeCards[0].answer == "Zero, one, two")
        #expect(saved.activeCards.map(\.sortIndex) == [0, 1])
        #expect(saved.updatedAt >= originalUpdatedAt)
        // Never synced → the removed card is really gone.
        #expect(try context.fetch(FetchDescriptor<Flashcard>()).allSatisfy { $0.id != removedID })
    }

    @Test func removingACardFromASyncedDeckLeavesATombstone() throws {
        let context = try makeContext()
        let creator = makeVM(context)
        fillValidDeck(creator)
        let deck = try #require(creator.save())
        deck.lastSyncedAt = .now
        deck.syncState = .synced
        let removedID = deck.activeCards[0].id

        let editor = makeVM(context, editing: deck)
        editor.deleteCard(cardID: removedID)
        _ = try #require(editor.save())

        let removed = try #require(deck.cards.first { $0.id == removedID })
        #expect(removed.deletedAt != nil)
        #expect(deck.cardCount == 1)
        #expect(deck.syncState == .locallyPersisted)
    }

    @Test func unchangedEditDoesNotBumpUpdatedAt() throws {
        let context = try makeContext()
        let creator = makeVM(context)
        fillValidDeck(creator)
        let deck = try #require(creator.save())
        let stamp = deck.updatedAt

        _ = try #require(makeVM(context, editing: deck).save())

        #expect(deck.updatedAt == stamp)
    }

    @Test func deleteCardAndUndo() throws {
        let vm = makeVM(try makeContext())
        fillValidDeck(vm)
        let first = vm.draft.cards[0]

        let removed = try #require(vm.deleteCard(cardID: first.id))
        #expect(vm.draft.cards.count == 1)
        vm.restoreCard(removed.card, at: removed.index)
        #expect(vm.draft.cards.first == first)
    }

    @Test func moveAndDuplicate() throws {
        let vm = makeVM(try makeContext())
        fillValidDeck(vm)
        let a = vm.draft.cards[0].id
        let b = vm.draft.cards[1].id

        vm.moveCard(a, onto: b)
        #expect(vm.draft.cards.map(\.id) == [b, a])
        vm.moveCard(a, onto: b)
        #expect(vm.draft.cards.map(\.id) == [a, b])

        let copy = try #require(vm.duplicateCard(cardID: b))
        #expect(vm.draft.cards.map(\.id) == [a, b, copy])
        #expect(vm.draft.cards[2].snippet == vm.draft.cards[1].snippet)
    }

    @Test func toggleSnippet() throws {
        let vm = makeVM(try makeContext())
        let id = vm.draft.cards[0].id
        vm.toggleSnippet(cardID: id)
        #expect(vm.draft.cards[0].snippet == SnippetDraft())
        vm.toggleSnippet(cardID: id)
        #expect(vm.draft.cards[0].snippet == nil)
    }

    @Test func starterDecksCannotBeEditedOrDeletedButCanBeHidden() throws {
        let context = try makeContext()
        let starter = try TestSupport.insertDeck(context, origin: .starter, prompts: ["a"])
        starter.syncState = .locallyPersisted
        try context.save()
        let backend = BackendFacade.localOnly(context: context)

        #expect(!starter.isEditable)
        #expect(throws: DeckBackendError.notEditable) {
            _ = try backend.saveDeck(DeckDraft(deck: starter))
        }
        #expect(throws: DeckBackendError.self) { try backend.deleteDeck(starter) }

        try backend.setHidden(true, deck: starter)
        #expect(starter.isHidden)
        try backend.setHidden(false, deck: starter)
        #expect(!starter.isHidden)
    }
}
