import Combine
import SwiftData
import SwiftUI

/// The "flashcard factory" UI (UC-01/02, Fig. 6): deck header and card
/// pager. Saves through DeckViewModel → FlashcardFactory → backend.
///
/// §3b (Nov 15): laid out like a quiz or study session, not a stock form:
/// the session top bar (✕, the deck's name as you type it, + card), Save
/// pinned at the bottom, and no mini-card strip. Reordering and the other
/// per-card actions live on Deck detail's card list; here each card has a
/// ⋯ menu.
///
///     (✕)        Heaps          (+)
///     ╭ pastel title note ─────────╮
///     ╭ card being edited ─────────╮
///     [            Save           ]
struct DeckBuilderView: View {
    @State private var viewModel: DeckViewModel
    let topics: [Topic]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var titleFocused: Bool

    @State private var page: PagerPage?
    @State private var focusRequest: FocusRequest?
    @State private var confirmDiscard = false
    @State private var undo: DeletedCard?
    @State private var savedCount = 0
    @State private var failedCount = 0
    /// Keyboard on screen (§3b): the page sheds everything but the card
    /// being written, so the field isn't squeezed to a sliver.
    @State private var keyboardUp = false

    /// Writing a card: only the card stays. Typing the title keeps the
    /// header and drops the rest.
    private var isWritingCard: Bool { keyboardUp && !titleFocused }

    private struct DeletedCard: Equatable {
        let card: CardDraft
        let index: Int
    }

    /// `startCardID`: open on that card (Edit from a card on Deck detail).
    init(viewModel: DeckViewModel, topics: [Topic], startCardID: UUID? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.topics = topics
        let start = startCardID ?? viewModel.draft.cards.first?.id
        _page = State(initialValue: start.map { .card($0) })
    }

    /// The bar names the deck as soon as it has a name.
    private var barTitle: String {
        let title = viewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        return viewModel.isEditing ? "Edit Deck" : "New Deck"
    }

    var body: some View {
        VStack(spacing: CodeySpacing.sm) {
            if !isWritingCard {
                DeckHeaderEditor(viewModel: viewModel, topics: topics, titleFocused: $titleFocused)
                    .padding(.horizontal, CodeySpacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))

                FieldErrorLabel(message: viewModel.error(for: .deckHasNoCards))
            }

            CardPagerView(
                viewModel: viewModel, page: $page, focusRequest: $focusRequest,
                showsPosition: !keyboardUp, onDelete: deleteCard
            )
            .frame(maxHeight: .infinity)
        }
        .padding(.top, CodeySpacing.xs)
        // Taps on bare paper close the keyboard (no keyboard toolbar).
        .background { Color.clear.contentShape(.rect).onTapGesture(perform: endEditing) }
        .codeyBar(.top) {
            // A sheet has no status bar above it: inset like Ask Codey's header.
            topBar.padding(.horizontal, CodeySpacing.md).padding(.top, CodeySpacing.md)
        }
        .codeyBar(.bottom) {
            // Off while typing: the keyboard would lift it over the card.
            if !keyboardUp {
                CodeyButton("Save", systemImage: "checkmark", kind: .primary, fullWidth: true, action: save)
                    .disabled(viewModel.uiState == .saving)
                    .accessibilityIdentifier("builder.save")
                    .padding(.horizontal, CodeySpacing.md)
                    .padding(.bottom, CodeySpacing.sm)
            }
        }
        .codeyPaperBackground()
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withCodeyAnimation(reduceMotion: reduceMotion) { keyboardUp = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withCodeyAnimation(reduceMotion: reduceMotion) { keyboardUp = false }
        }
        .overlay(alignment: .bottom) { undoToast }
        .codeyConfirm("Discard changes?", isPresented: $confirmDiscard, cancelTitle: "Keep Editing") {
            [CodeyDialog.Action("Discard Changes", isDestructive: true) { dismiss() }]
        }
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.error, trigger: failedCount)
        .onChange(of: viewModel.draft.cards.map(\.id)) { _, ids in
            // Keep the pager on a real page after deletes.
            if case .card(let id) = page, !ids.contains(id) {
                page = ids.first.map { .card($0) } ?? .newCard
            }
        }
        // Its own layer for the card's menus and Discard, above the sheet.
        .codeyOverlayHost()
    }

    /// The session bar (as in quiz and study): ✕, the deck's name, + card.
    private var topBar: some View {
        SessionTopBar(closeLabel: "Cancel", closeHint: nil, closeID: "builder.cancel", close: cancel) {
            Text(barTitle)
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .onTapGesture(perform: endEditing)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("builder.barTitle")
        } trailing: {
            CircleIconButton(systemImage: "plus", label: "Add Card", kind: .soft, action: addCard)
                .accessibilityIdentifier("builder.addCard")
        }
    }

    // MARK: Actions

    private func cancel() {
        if viewModel.hasUnsavedChanges { confirmDiscard = true } else { dismiss() }
    }

    private func addCard() {
        endEditing()
        let id = viewModel.addCard(after: page.flatMap { if case .card(let id) = $0 { id } else { nil } })
        withCodeyAnimation(reduceMotion: reduceMotion) { page = .card(id) }
    }

    private func endEditing() {
        titleFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func save() {
        if viewModel.save() != nil {
            savedCount += 1
            dismiss()
            return
        }
        failedCount += 1
        if viewModel.error(for: .deckTitle) != nil {
            titleFocused = true
        } else if let cardID = viewModel.firstInvalidCardID {
            withCodeyAnimation(reduceMotion: reduceMotion) { page = .card(cardID) }
            focusRequest = FocusRequest.firstError(in: viewModel, cardID: cardID)
        }
    }

    private func deleteCard(_ id: UUID) {
        guard let removed = viewModel.deleteCard(cardID: id) else { return }
        let deleted = DeletedCard(card: removed.card, index: removed.index)
        withCodeyAnimation(reduceMotion: reduceMotion) { undo = deleted }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if undo == deleted {
                withCodeyAnimation(reduceMotion: reduceMotion) { undo = nil }
            }
        }
    }

    @ViewBuilder
    private var undoToast: some View {
        if let undo {
            HStack(spacing: CodeySpacing.md) {
                Text("Card deleted")
                    .font(.codeyCallout)
                Button("Undo") {
                    viewModel.restoreCard(undo.card, at: undo.index)
                    page = .card(undo.card.id)
                    withCodeyAnimation(reduceMotion: reduceMotion) { self.undo = nil }
                }
                .fontWeight(.semibold)
                .tint(CodeyColor.brand)
            }
            .padding(.horizontal, CodeySpacing.md)
            .padding(.vertical, CodeySpacing.sm + CodeySpacing.xs)
            .codeyFloatingSurface()
            .padding(.bottom, CodeySpacing.xxl + CodeySpacing.xl)
            .transition(CodeyMotion.popTransition(reduceMotion: reduceMotion))
            .accessibilityElement(children: .contain)
            .onAppear { UIAccessibility.post(notification: .announcement, argument: "Card deleted. Undo available.") }
        }
    }
}

#Preview("New deck") {
    let container = ModelContainerFactory.makePreview()
    let topics = (try? container.mainContext.fetch(FetchDescriptor<Topic>())) ?? []
    return DeckBuilderView(
        viewModel: DeckViewModel(
            backend: BackendFacade.localOnly(context: container.mainContext),
            knownTopicIds: Set(topics.map(\.id))
        ),
        topics: topics
    )
    .modelContainer(container)
}

