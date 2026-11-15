import SwiftData
import SwiftUI

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
        List {
            // The deck in its topic's pastel, as on Play and the library (S41).
            Section {
                VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                    HStack(alignment: .top) {
                        Icon(topic?.iconName ?? "rectangle.stack", size: 26, relativeTo: .title2)
                        Spacer()
                        if deck.origin == .user || deck.isHidden {
                            DeckStatusChip(deck: deck)
                        }
                    }
                    Text(deck.title)
                        .font(.codeyTitle.weight(.semibold))
                    Text([topic?.title, deck.cardCount.counted("card")].compactMap { $0 }.joined(separator: ", "))
                        .font(.codeySubheadline)
                    ProgressBar(value: deck.progressRate, tint: hue.fill, height: 8, track: hue.fill.opacity(0.2))
                    Text("\(deck.progressRate.percentText) progress")
                        .font(.codeySubheadline)
                }
                .foregroundStyle(hue.ink)
                .padding(.vertical, CodeySpacing.xs)
                .accessibilityElement(children: .combine)
                .listRowBackground(hue.soft)
            }

            StudyLauncherSection(deck: deck, hue: hue) { start in
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
        .listSectionSpacing(.compact)
        .contentMargins(.top, CodeySpacing.xs, for: .scrollContent)
        .codeyListBackground()
        // The colored card shows the title, so the bar shows only buttons;
        // navigationTitle still names the page for back and VoiceOver.
        .navigationTitle(deck.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
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
                do {
                    try backend.deleteDeck(deck)
                    dismiss()
                } catch {
                    actionError = (error as? LocalizedError)?.errorDescription ?? "Couldn't delete this deck."
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
