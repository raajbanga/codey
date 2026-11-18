import SwiftData
import SwiftUI

/// A deck's cards (read-only for starter decks), with Edit / Hide / Delete.
///
/// §3b (Nov 15): a page of notes, not a grouped List. The round buttons,
/// the deck's HeroCard (topic, cards, progress), the Study note, then every
/// card as its own long bento. For your own
/// decks each card carries its actions (Edit, Duplicate, Move, Delete),
/// which used to live in the builder's mini-card strip.
struct DeckDetailView: View {
    let deck: FlashcardDeck
    let topic: Topic?

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Topic.title) private var topics: [Topic]

    @State private var confirmDelete = false
    @State private var actionError: String?
    @State private var expandedCardID: UUID?
    /// Opens the builder on this card.
    @State private var editingCard: EditTarget?
    @State private var cardToDelete: Flashcard?

    private struct EditTarget: Identifiable {
        let cardID: UUID?
        var id: String { cardID?.uuidString ?? "deck" }
    }
    @Environment(Router.self) private var router
    @Environment(BackendFacade.self) private var backend

    private var hue: CodeyColor.TopicHue { .of(topicID: deck.topicId) }

    var body: some View {
        // Never-synced decks are hard-deleted, and a deleted model must not
        // be read while the pop animation is still showing this screen.
        if deck.isDeleted || deck.modelContext == nil {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        CodeyPage(deck.title) {
            if deck.isEditable {
                CircleIconButton(systemImage: "pencil", label: "Edit", kind: .soft) { editingCard = EditTarget(cardID: nil) }
                    .disabled(!deck.canEdit)
                    .accessibilityIdentifier("deck.edit")
                CodeyMenu(.icon("ellipsis", label: "Deck actions")) {
                    CodeyMenuItem("Delete Deck", systemImage: "trash", isDestructive: true, isDisabled: !deck.canDelete) { confirmDelete = true }
                }
                .accessibilityIdentifier("deck.actions")
            } else {
                CircleIconButton(systemImage: deck.isHidden ? "eye" : "eye.slash", label: deck.isHidden ? "Restore" : "Hide", kind: .soft) {
                    $actionError.attempt { try backend.setHidden(!deck.isHidden, deck: deck) }
                }
            }
        } hero: {
            hero
        } content: {
            StudyLauncherSection(deck: deck, hue: hue) { start in
                router.study = StudyRequest(deck: deck, start: start)
            }
        } trailing: {
            // iPad landscape: the cards are the second column.
            VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                SectionTitle("Cards")
                ForEach(deck.activeCards) { card in
                    CardRow(
                        card: card,
                        isExpanded: expandedCardID == card.id,
                        toggleHidden: { $actionError.attempt { try backend.setHidden(!card.isHidden, card: card) } },
                        actions: deck.isEditable && deck.canEdit ? actions(for: card) : nil
                    )
                    .onTapGesture { toggle(card) }
                }
            }
        }
        .sheet(item: $editingCard) { target in
            DeckBuilderView(viewModel: editor(), topics: topics, startCardID: target.cardID)
        }
        .codeyConfirm("Delete this card?", isPresented: $cardToDelete.isPresent(), message: "This can't be undone.") {
            [CodeyDialog.Action("Delete Card", isDestructive: true) {
                if let card = cardToDelete { change { $0.deleteCard(cardID: card.id) } }
            }]
        }
        .codeyConfirm("Delete \"\(deck.title)\"?", isPresented: $confirmDelete, message: "All \(deck.cardCount) cards will be deleted. This can't be undone.") {
            [CodeyDialog.Action("Delete Deck", isDestructive: true) {
                do {
                    try backend.deleteDeck(deck)
                    dismiss()
                } catch {
                    actionError = (error as? LocalizedError)?.errorDescription ?? "Couldn't delete this deck."
                }
            }]
        }
        .errorAlert($actionError)
    }
}

extension DeckDetailView {
    /// The deck in its topic's pastel, as on Play and the library (S41).
    fileprivate var hero: some View {
        let (mastered, total) = deck.mastery
        return HeroCard(
            title: deck.title,
            subtitle: [topic?.title, deck.cardCount.counted("card")].compactMap { $0 }.joined(separator: ", "),
            icon: topic?.iconName ?? "rectangle.stack",
            hue: hue,
            progress: total == 0 ? 0 : Double(mastered) / Double(total),
            caption: "\(mastered) of \(total) cards mastered"
        ) {
            if deck.origin == .user || deck.isHidden {
                DeckStatusChip(deck: deck)
            }
        }
    }

    fileprivate func toggle(_ card: Flashcard) {
        withAnimation(CodeyMotion.snappy) {
            expandedCardID = expandedCardID == card.id ? nil : card.id
        }
    }

    fileprivate func editor() -> DeckViewModel {
        DeckViewModel(backend: backend, knownTopicIds: Set(topics.map(\.id)), editing: deck)
    }

    /// One card change saved straight away, through the same view model
    /// and validation as the builder.
    fileprivate func change(_ edit: (DeckViewModel) -> Void) {
        let viewModel = editor()
        edit(viewModel)
        if viewModel.save() == nil {
            actionError = viewModel.error(for: .deckHasNoCards) ?? "Couldn't update this deck."
        }
    }

    fileprivate func actions(for card: Flashcard) -> CardRow.Actions {
        let cards = deck.activeCards
        let index = cards.firstIndex { $0.id == card.id } ?? 0
        let previous = index > 0 ? cards[index - 1].id : nil
        let next = index + 1 < cards.count ? cards[index + 1].id : nil
        return CardRow.Actions(
            edit: { editingCard = EditTarget(cardID: card.id) },
            duplicate: { change { $0.duplicateCard(cardID: card.id) } },
            moveUp: previous.map { target in { change { $0.moveCard(card.id, onto: target) } } },
            moveDown: next.map { target in { change { $0.moveCard(card.id, onto: target) } } },
            delete: { cardToDelete = card }
        )
    }
}

/// One card as a long bento: tags, the prompt (tap for the answer), and
/// for your own decks a ⋯ menu with the card's actions.
private struct CardRow: View {
    struct Actions {
        let edit: () -> Void
        let duplicate: () -> Void
        let moveUp: (() -> Void)?
        let moveDown: (() -> Void)?
        let delete: () -> Void
    }

    let card: Flashcard
    let isExpanded: Bool
    let toggleHidden: () -> Void
    let actions: Actions?

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(spacing: CodeySpacing.xs) {
                if let difficulty = card.difficulty {
                    CodeyChip(tier: difficulty)
                }
                if let snippet = card.codeSnippet {
                    CodeyChip(snippet.language.displayName, systemImage: "chevron.left.forwardslash.chevron.right")
                }
                if card.isHidden {
                    CodeyChip("Hidden", systemImage: "eye.slash")
                } else if card.isMastered {
                    CodeyChip("Mastered", systemImage: "checkmark.seal.fill", variant: .success)
                }
                Spacer(minLength: 0)
                menu
            }
            if isExpanded {
                CardMarkdownView(markdown: card.prompt, snippet: card.codeSnippet)
                HairlineDivider()
                CardMarkdownView(markdown: card.answer)
            } else {
                Text(CardMarkdownView.inlinePreview(card.prompt))
                    .font(.codeyBody)
                    .foregroundStyle(CodeyColor.textPrimary)
                    .lineLimit(3)
            }
        }
        .codeyCard()
        // A hidden card stays in the list, faded: it's out of study.
        .opacity(card.isHidden ? 0.55 : 1)
        .contentShape(.rect(cornerRadius: CodeyRadius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityHint(isExpanded ? "Collapses the answer" : "Shows the answer")
    }

    /// Hide takes the card out of study without deleting it (Show puts it
    /// back); it sits above Delete. Your own decks add Edit, Duplicate, Move.
    private var menu: some View {
        CodeyMenu(.icon("ellipsis", label: "Card actions", compact: true)) {
            if let actions {
                CodeyMenuItem("Edit", systemImage: "pencil", action: actions.edit)
                CodeyMenuItem("Duplicate", systemImage: "plus.square.on.square", action: actions.duplicate)
                if let moveUp = actions.moveUp { CodeyMenuItem("Move Up", systemImage: "arrow.up", action: moveUp) }
                if let moveDown = actions.moveDown { CodeyMenuItem("Move Down", systemImage: "arrow.down", action: moveDown) }
            }
            CodeyMenuItem(card.isHidden ? "Show Card" : "Hide Card", systemImage: card.isHidden ? "eye" : "eye.slash", action: toggleHidden)
            if let actions {
                CodeyMenuItem("Delete", systemImage: "trash", isDestructive: true, action: actions.delete)
            }
        }
        .accessibilityIdentifier("card.actions")
    }
}
