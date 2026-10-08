import Foundation

/// What the deck builder needs from storage. BackendFacade implements it;
/// DeckViewModel depends only on this protocol.
@MainActor
protocol DeckBackend {
    /// Persists the draft locally FIRST (FR-44). Creates the deck when
    /// draft.deckID is nil, otherwise updates it. Cards go through
    /// FlashcardFactory. Leaves the deck LocallyPersisted.
    func saveDeck(_ draft: DeckDraft) throws -> FlashcardDeck
    /// FR-12. Throws if the deck's state doesn't allow deleting it.
    func deleteDeck(_ deck: FlashcardDeck) throws
    /// FR-15. Starter decks only.
    func setHidden(_ hidden: Bool, deck: FlashcardDeck) throws
}

enum DeckBackendError: Error, LocalizedError, Equatable {
    case deckNotFound
    case notEditable
    case deleteNotAllowed(String)
    case invalid([FieldError])

    var errorDescription: String? {
        switch self {
        case .deckNotFound: "This deck no longer exists."
        case .notEditable: "Starter decks can't be edited."
        case .deleteNotAllowed(let reason): reason
        case .invalid: "Some fields need fixing."
        }
    }
}
