import Foundation

/// A page in the builder's card pager.
enum PagerPage: Hashable {
    case card(UUID)
    case newCard
}

/// Where to send focus after a failed save.
struct FocusRequest: Equatable {
    enum Field: Equatable {
        case prompt, answer, snippet
    }

    let cardID: UUID
    let field: Field

    /// The first failing field of `cardID`, in on-screen order.
    @MainActor
    static func firstError(in viewModel: DeckViewModel, cardID: UUID) -> FocusRequest? {
        if viewModel.error(for: .cardPrompt(cardID)) != nil { return FocusRequest(cardID: cardID, field: .prompt) }
        if viewModel.error(for: .snippetLanguage(cardID)) != nil || viewModel.error(for: .snippetSource(cardID)) != nil {
            return FocusRequest(cardID: cardID, field: .snippet)
        }
        if viewModel.error(for: .cardAnswer(cardID)) != nil { return FocusRequest(cardID: cardID, field: .answer) }
        return nil
    }
}
