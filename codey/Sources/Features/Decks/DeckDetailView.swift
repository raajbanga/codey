import SwiftData
import SwiftUI
import os

/// A deck's cards (read-only for starter decks), with Edit / Hide / Delete.
struct DeckDetailView: View {
    let deck: FlashcardDeck
    let topic: Topic?

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Topic.title) private var topics: [Topic]

    @State private var isEditing = false
    @State private var confirmDelete = false
    @State private var actionError: String?
    @State private var expandedCardID: UUID?
    @Environment(Router.self) private var router
    @Environment(BackendFacade.self) private var backend

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                    HStack {
                        if let topic {
                            Label(topic.title, systemImage: topic.iconName)
                                .font(.codeySubheadline)
                                .foregroundStyle(CodeyColor.textSecondary)
                        }
                        Spacer()
                        DeckStatusChip(deck: deck)
                    }
                    ProgressBar(value: deck.progressRate, label: "\(deck.cardCount.counted("card")) · \(deck.progressRate.percentText) progress")
                }
                .padding(.vertical, CodeySpacing.xs)
            }

            StudyLauncherSection(deck: deck) { start in
                router.study = StudyRequest(deck: deck, start: start)
            }

            Section("Cards") {
                ForEach(deck.activeCards) { card in
                    CardRow(card: card, isExpanded: expandedCardID == card.id)
                        .contentShape(.rect)
                        .onTapGesture {
                            withAnimation(CodeyMotion.snappy) {
                                expandedCardID = expandedCardID == card.id ? nil : card.id
                            }
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
        .codeyListBackground()
        .navigationTitle(deck.title)
        // Inline: deck names are long and a large title truncates them.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if deck.isEditable {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { isEditing = true }
                        .disabled(!deck.canEdit)
                        .accessibilityIdentifier("deck.edit")
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Delete Deck", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        .disabled(!deck.canDelete)
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button(deck.isHidden ? "Restore" : "Hide", systemImage: deck.isHidden ? "eye" : "eye.slash") {
                        $actionError.attempt { try backend.setHidden(!deck.isHidden, deck: deck) }
                    }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            DeckBuilderView(
                viewModel: DeckViewModel(backend: backend, knownTopicIds: Set(topics.map(\.id)), editing: deck),
                topics: topics
            )
        }
        .confirmationDialog("Delete \"\(deck.title)\"?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Deck", role: .destructive) {
                // Leave the screen first: a hard-deleted model must not be
                // read by a view that's still on screen.
                let backend = backend
                let deck = deck
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    do { try backend.deleteDeck(deck) } catch {
                        Logger.persistence.error("Deleting deck failed: \(String(describing: error))")
                    }
                }
            }
            .disabled(!deck.canDelete)
        } message: {
            Text("All \(deck.cardCount) cards will be deleted. This can't be undone.")
        }
        .errorAlert($actionError)
    }
}

private struct CardRow: View {
    let card: Flashcard
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(spacing: CodeySpacing.xs) {
                if let difficulty = card.difficulty {
                    CodeyChip(tier: difficulty)
                }
                if let snippet = card.codeSnippet {
                    CodeyChip(snippet.language.displayName, systemImage: "chevron.left.forwardslash.chevron.right")
                }
                if card.isMastered {
                    CodeyChip("Mastered", systemImage: "checkmark.seal.fill", variant: .success)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .foregroundStyle(CodeyColor.textSecondary)
                    .accessibilityHidden(true)
            }
            if isExpanded {
                CardMarkdownView(markdown: card.prompt, snippet: card.codeSnippet)
                Divider()
                CardMarkdownView(markdown: card.answer)
            } else {
                Text(CardMarkdownView.inlinePreview(card.prompt))
                    .font(.codeyBody)
                    .foregroundStyle(CodeyColor.textPrimary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, CodeySpacing.xs)
        .accessibilityElement(children: isExpanded ? .contain : .combine)
        .accessibilityHint(isExpanded ? "Collapses the answer" : "Shows the answer")
    }
}
