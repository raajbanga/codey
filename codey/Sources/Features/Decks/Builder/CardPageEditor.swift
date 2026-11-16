import SwiftUI

/// One card in the pager, built like the study card it becomes (§3b,
/// Nov 15 redo): a FlipCard with the prompt on the front and the answer on
/// the back, typed straight onto the card (Notion-style Markdown). Each face
/// has the tier tag and ⋯ (Duplicate, Remove Code, Delete) at the top, as
/// the study card shows its tier, and the flip button at the bottom. The rendered preview lives on Deck
/// detail now (Show Answer), not here.
///
///     ╭─────────────────────────────────────╮
///     │ Prompt                 [Easy]  (⋯) │
///     │ What does `defer` do?              │
///     │ [Swift]                  3/20 lines│
///     │ ┌ code ───────────────────────────┐ │
///     │ [+ Add Code]           [↻ Answer]  │
///     ╰─────────────────────────────────────╯
struct CardPageEditor: View {
    @Binding var card: CardDraft
    let viewModel: DeckViewModel
    @Binding var focusRequest: FocusRequest?
    let duplicate: () -> Void
    let delete: () -> Void

    @State private var flipped = false
    @State private var focusPrompt = false
    @State private var focusAnswer = false

    var body: some View {
        ScrollView {
            FlipCard(isFlipped: flipped) {
                face(front: true) {
                    MarkdownTextEditor(
                        title: "Prompt",
                        text: $card.prompt,
                        limit: ModelValidator.Limits.prompt.upperBound,
                        errorMessage: viewModel.error(for: .cardPrompt(card.id)),
                        focusRequested: $focusPrompt
                    )
                    .accessibilityIdentifier("card.prompt")
                    codeSection
                }
            } back: {
                face(front: false) {
                    MarkdownTextEditor(
                        title: "Answer",
                        text: $card.answer,
                        limit: ModelValidator.Limits.answer.upperBound,
                        errorMessage: viewModel.error(for: .cardAnswer(card.id)),
                        focusRequested: $focusAnswer
                    )
                    .accessibilityIdentifier("card.answer")
                }
            }
            .padding(.vertical, CodeySpacing.xs)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .onChange(of: focusRequest, initial: true) { _, request in
            guard let request, request.cardID == card.id else { return }
            flipped = request.field == .answer
            switch request.field {
            case .prompt: focusPrompt = true
            case .answer: focusAnswer = true
            case .snippet: break
            }
            focusRequest = nil
        }
    }

    // MARK: Face

    private func face(front: Bool, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(spacing: CodeySpacing.xs) {
                // Same label and colors as the study card's faces.
                Text(front ? "Prompt" : "Answer")
                    .font(.codeySubheadline.weight(.medium))
                    .foregroundStyle(front ? CodeyColor.brand : CodeyColor.success)
                Spacer(minLength: 0)
                // Where the study card shows its tier.
                tierMenu
                actionsMenu
            }
            content()
            Spacer(minLength: 0)
            // Like turning the card over in study: at the bottom, named for
            // the side it shows next.
            HStack {
                if front, card.snippet == nil { addCodeButton }
                Spacer(minLength: 0)
                CodeyButton(front ? "Answer" : "Prompt", systemImage: "arrow.left.arrow.right", kind: .secondary, compact: true) {
                    flipped.toggle()
                    // Typing follows the face you're looking at.
                    if flipped { focusAnswer = true } else { focusPrompt = true }
                }
                .accessibilityLabel(front ? "Flip to answer" : "Flip to prompt")
                .accessibilityIdentifier("card.flip")
            }
        }
        .padding(CodeySpacing.lg)
        .frame(maxWidth: .infinity, minHeight: StudyCardView.minHeight, alignment: .topLeading)
        .codeyNote(edge: viewModel.errorCount(cardID: card.id) > 0 ? CodeyColor.danger : nil)
    }

    private var tierMenu: some View {
        CodeyMenu(card.difficulty.map { .value($0.style.label, systemImage: $0.style.symbol, variant: .tier($0)) } ?? .placeholder("Tier")) {
            CodeyMenuItem.choices(
                [nil] + Difficulty.allCases.map(Optional.some),
                selection: $card.difficulty,
                title: { $0?.style.label ?? "None" },
                systemImage: { $0?.style.symbol }
            )
        }
        .accessibilityLabel("Tier: \(card.difficulty?.style.label ?? "None")")
    }

    private var actionsMenu: some View {
        CodeyMenu(.icon("ellipsis", label: "Card actions", compact: true)) {
            CodeyMenuItem("Duplicate", systemImage: "plus.square.on.square", action: duplicate)
            if card.snippet != nil {
                CodeyMenuItem("Remove Code", systemImage: "chevron.left.forwardslash.chevron.right", action: toggleSnippet)
            }
            CodeyMenuItem("Delete", systemImage: "trash", isDestructive: true, action: delete)
        }
        .accessibilityIdentifier("card.actions")
    }

    // MARK: Code

    @ViewBuilder
    private var codeSection: some View {
        if let snippet = card.snippet {
            HStack {
                // The same tag as on Deck detail's card rows.
                CodeyMenu(.value(snippet.language.displayName, systemImage: "chevron.left.forwardslash.chevron.right")) {
                    CodeyMenuItem.choices(
                        CodeLanguage.allCases,
                        selection: snippetBinding(\.language, default: snippet.language),
                        title: \.displayName
                    )
                }
                .accessibilityLabel("Language: \(snippet.language.displayName)")
                .accessibilityIdentifier("card.language")
                Spacer(minLength: 0)
                LimitCounter(
                    count: ModelValidator.lineCount(snippet.source),
                    limit: ModelValidator.Limits.snippetMaxLines,
                    unit: "lines"
                )
            }
            CodeEditorView(text: snippetBinding(\.source, default: ""), language: snippet.language)
                .frame(height: 200)
                .clipShape(.codey(CodeyRadius.md))
                .errorBorder(viewModel.error(for: .snippetSource(card.id)) != nil, radius: CodeyRadius.md)
                .accessibilityLabel("\(snippet.language.displayName) code")
                .accessibilityIdentifier("card.codeEditor")
            FieldErrorLabel(message: viewModel.error(for: .snippetLanguage(card.id)))
            FieldErrorLabel(message: viewModel.error(for: .snippetSource(card.id)))
        }
    }

    private var addCodeButton: some View {
        CodeyButton("Add Code", systemImage: "plus", kind: .secondary, compact: true, action: toggleSnippet)
            .accessibilityIdentifier("card.addCode")
    }

    private func toggleSnippet() {
        withAnimation(CodeyMotion.snappy) { viewModel.toggleSnippet(cardID: card.id) }
    }

    private func snippetBinding<Value>(_ keyPath: WritableKeyPath<SnippetDraft, Value>, default fallback: Value) -> Binding<Value> {
        Binding(
            get: { card.snippet?[keyPath: keyPath] ?? fallback },
            set: { card.snippet?[keyPath: keyPath] = $0 }
        )
    }
}
