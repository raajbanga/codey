import Foundation
import Observation

/// Drives the deck builder (UC-01/02/03, Fig. 6). Observation replaces the
/// doc's @Published; same role.
@MainActor
@Observable
final class DeckViewModel {
    enum UIState: Equatable {
        case idle
        case saving
        case savedSuccess
        case failed(String)
    }

    var draft: DeckDraft {
        didSet { draftDidChange() }
    }
    private(set) var fieldErrors: [ValidationField: String] = [:]
    private(set) var uiState: UIState = .idle
    /// Live validation starts only after the first failed save, so the first
    /// keystroke doesn't flash errors.
    private(set) var hasAttemptedSave = false

    let isEditing: Bool
    private let original: DeckDraft
    private let backend: any DeckBackend
    private let knownTopicIds: Set<String>
    private let liveValidationDelay: Duration
    private var liveValidationTask: Task<Void, Never>?

    init(
        backend: any DeckBackend,
        knownTopicIds: Set<String>,
        editing deck: FlashcardDeck? = nil,
        defaultTopicId: String? = nil,
        liveValidationDelay: Duration = .milliseconds(300)
    ) {
        let draft = deck.map(DeckDraft.init(deck:))
            ?? .new(topicId: defaultTopicId ?? knownTopicIds.sorted().first ?? "")
        self.draft = draft
        self.original = draft
        self.isEditing = deck != nil
        self.backend = backend
        self.knownTopicIds = knownTopicIds
        self.liveValidationDelay = liveValidationDelay
    }

    var hasUnsavedChanges: Bool { draft != original }

    // MARK: Errors

    func error(for field: ValidationField) -> String? { fieldErrors[field] }

    /// Cards with at least one error, for the pager/thumbnail red dots.
    func errorCount(cardID: UUID) -> Int {
        fieldErrors.keys.filter { $0.cardID == cardID }.count
    }

    /// Where Save sends the user after a validation failure.
    var firstInvalidCardID: UUID? {
        draft.cards.first { errorCount(cardID: $0.id) > 0 }?.id
    }

    // MARK: Cards

    @discardableResult
    func addCard(after cardID: UUID? = nil) -> UUID {
        let card = CardDraft()
        if let cardID, let index = draft.cards.firstIndex(where: { $0.id == cardID }) {
            draft.cards.insert(card, at: index + 1)
        } else {
            draft.cards.append(card)
        }
        return card.id
    }

    @discardableResult
    func duplicateCard(cardID: UUID) -> UUID? {
        guard let index = draft.cards.firstIndex(where: { $0.id == cardID }) else { return nil }
        let source = draft.cards[index]
        let copy = CardDraft(prompt: source.prompt, answer: source.answer, snippet: source.snippet, difficulty: source.difficulty)
        draft.cards.insert(copy, at: index + 1)
        return copy.id
    }

    /// FR-13 (in the draft; persisted on Save). Returns what's needed to undo.
    @discardableResult
    func deleteCard(cardID: UUID) -> (card: CardDraft, index: Int)? {
        guard let index = draft.cards.firstIndex(where: { $0.id == cardID }) else { return nil }
        let card = draft.cards.remove(at: index)
        fieldErrors = fieldErrors.filter { $0.key.cardID != cardID }
        return (card, index)
    }

    func restoreCard(_ card: CardDraft, at index: Int) {
        draft.cards.insert(card, at: min(max(index, 0), draft.cards.count))
    }

    /// Moves `cardID` to where `targetID` is (drag-and-drop in the strip).
    func moveCard(_ cardID: UUID, onto targetID: UUID) {
        guard cardID != targetID,
              let from = draft.cards.firstIndex(where: { $0.id == cardID }),
              let to = draft.cards.firstIndex(where: { $0.id == targetID }) else { return }
        draft.cards.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
    }

    func toggleSnippet(cardID: UUID) {
        guard let index = draft.cards.firstIndex(where: { $0.id == cardID }) else { return }
        draft.cards[index].snippet = draft.cards[index].snippet == nil ? SnippetDraft() : nil
    }

    // MARK: Validation

    @discardableResult
    func validateNow() -> ValidationResult {
        let errors = ModelValidator.validateDeck(
            title: draft.title,
            topicId: draft.topicId,
            cards: draft.cards.map(\.validationFields),
            knownTopicIds: knownTopicIds
        )
        fieldErrors = errors.keyed(by: \.field).mapValues(\.message)
        return errors
    }

    private func draftDidChange() {
        if case .failed = uiState { uiState = .idle }
        guard hasAttemptedSave else { return }
        liveValidationTask?.cancel()
        let delay = liveValidationDelay
        liveValidationTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.validateNow()
        }
    }

    // MARK: Save / delete

    /// Validates, then saves through the backend. nil on failure (errors are
    /// in fieldErrors / uiState).
    @discardableResult
    func save() -> FlashcardDeck? {
        if isEditing {
            return updateDeck()
        }
        return createDeck(title: draft.title, topic: draft.topicId, cardData: draft.cards)
    }

    /// Name per the sequence diagram (Fig. 6): createDeck(title, topic, cardData).
    @discardableResult
    func createDeck(title: String, topic: String, cardData: [CardDraft]) -> FlashcardDeck? {
        draft.title = title
        draft.topicId = topic
        draft.cards = cardData
        return persist()
    }

    /// FR-11: same flow for an existing deck (draft.deckID is set).
    @discardableResult
    func updateDeck() -> FlashcardDeck? {
        persist()
    }

    private func persist() -> FlashcardDeck? {
        hasAttemptedSave = true
        liveValidationTask?.cancel()
        guard validateNow().isEmpty else {
            uiState = .failed("Fix the highlighted fields.")
            return nil
        }
        uiState = .saving
        do {
            let deck = try backend.saveDeck(draft)
            uiState = .savedSuccess
            return deck
        } catch DeckBackendError.invalid(let errors) {
            fieldErrors = errors.keyed(by: \.field).mapValues(\.message)
            uiState = .failed("Fix the highlighted fields.")
        } catch {
            uiState = .failed(error.localizedDescription)
        }
        return nil
    }
}

extension ValidationField {
    /// The card a field belongs to, if any.
    var cardID: UUID? {
        switch self {
        case .cardPrompt(let id), .cardAnswer(let id), .snippetSource(let id), .snippetLanguage(let id): id
        case .deckTitle, .deckTopic, .deckHasNoCards, .displayName, .feedback, .groupName, .inviteCode: nil
        }
    }
}
