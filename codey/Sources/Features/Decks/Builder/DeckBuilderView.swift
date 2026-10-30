import SwiftData
import SwiftUI

/// The "flashcard factory" UI (UC-01/02, Fig. 6): deck header, card pager,
/// thumbnail strip. Saves through DeckViewModel → FlashcardFactory → backend.
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

    private struct DeletedCard: Equatable {
        let card: CardDraft
        let index: Int
    }

    init(viewModel: DeckViewModel, topics: [Topic]) {
        _viewModel = State(initialValue: viewModel)
        self.topics = topics
        _page = State(initialValue: viewModel.draft.cards.first.map { .card($0.id) })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: CodeySpacing.sm) {
                DeckHeaderEditor(viewModel: viewModel, topics: topics, titleFocused: $titleFocused)
                    .padding(.horizontal, CodeySpacing.md)

                FieldErrorLabel(message: viewModel.error(for: .deckHasNoCards))

                CardPagerView(viewModel: viewModel, page: $page, focusRequest: $focusRequest)
                    .frame(maxHeight: .infinity)

                CardThumbnailStrip(viewModel: viewModel, page: $page, onDelete: deleteCard)
            }
            .padding(.top, CodeySpacing.sm)
            .codeyPaperBackground()
            .navigationTitle(viewModel.isEditing ? "Edit Deck" : "New Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if viewModel.hasUnsavedChanges { confirmDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(viewModel.uiState == .saving)
                        .accessibilityIdentifier("builder.save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        titleFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .overlay(alignment: .bottom) { undoToast }
            .confirmationDialog("Discard changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
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
        }
    }

    // MARK: Actions

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
            .padding(.bottom, 104)
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
