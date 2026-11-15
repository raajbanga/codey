import SwiftUI

/// One card in the pager, shaped like the real study card (D15). Front =
/// prompt + optional code, Back = answer. Edit/Preview shows exactly what
/// study will render (CardMarkdownView).
struct CardPageEditor: View {
    @Binding var card: CardDraft
    let viewModel: DeckViewModel
    @Binding var focusRequest: FocusRequest?

    enum Side: String, CaseIterable, Identifiable {
        case front = "Front"
        case back = "Back"
        var id: String { rawValue }
    }

    @State private var side: Side = .front
    @State private var isPreviewing = false
    @State private var focusPrompt = false
    @State private var focusAnswer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.md) {
                header
                if isPreviewing {
                    preview
                } else if side == .front {
                    frontEditor
                } else {
                    backEditor
                }
            }
            .padding(CodeySpacing.md)
            .background(CodeyColor.surfaceRaised, in: .codey(CodeyRadius.lg))
            .errorBorder(viewModel.errorCount(cardID: card.id) > 0, radius: CodeyRadius.lg)
            .padding(.vertical, CodeySpacing.xs)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .onChange(of: focusRequest, initial: true) { _, request in
            guard let request, request.cardID == card.id else { return }
            isPreviewing = false
            switch request.field {
            case .prompt:
                side = .front
                focusPrompt = true
            case .snippet:
                side = .front
            case .answer:
                side = .back
                focusAnswer = true
            }
            focusRequest = nil
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: CodeySpacing.sm) {
            ChoiceChips("Side", selection: $side)
                .accessibilityIdentifier("card.side")

            Spacer(minLength: 0)

            Menu {
                Picker("Tier", selection: $card.difficulty) {
                    Text("None").tag(Difficulty?.none)
                    ForEach(Difficulty.allCases, id: \.self) { tier in
                        Label(tier.style.label, systemImage: tier.style.symbol).tag(Difficulty?.some(tier))
                    }
                }
            } label: {
                if let tier = card.difficulty {
                    CodeyChip(tier: tier)
                } else {
                    CodeyChip("Tier", systemImage: "tag")
                }
            }
            .accessibilityLabel("Tier: \(card.difficulty?.style.label ?? "None")")

            Button {
                withAnimation(CodeyMotion.snappy) { isPreviewing.toggle() }
            } label: {
                Image(systemName: isPreviewing ? "pencil" : "eye")
                    .foregroundStyle(CodeyColor.brand)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPreviewing ? "Edit card" : "Preview card")
        }
    }

    // MARK: Faces

    private var frontEditor: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.md) {
            MarkdownTextEditor(
                title: "Prompt",
                text: $card.prompt,
                limit: ModelValidator.Limits.prompt.upperBound,
                errorMessage: viewModel.error(for: .cardPrompt(card.id)),
                focusRequested: $focusPrompt
            )
            .accessibilityIdentifier("card.prompt")

            if ModelValidator.containsCodeFence(card.prompt) {
                Label("Tip: use Add code for syntax-highlighted examples.", systemImage: "lightbulb")
                    .font(.codeyCaption)
                    .foregroundStyle(CodeyColor.textSecondary)
            }

            codeSection
        }
    }

    private var backEditor: some View {
        MarkdownTextEditor(
            title: "Answer",
            text: $card.answer,
            limit: ModelValidator.Limits.answer.upperBound,
            errorMessage: viewModel.error(for: .cardAnswer(card.id)),
            focusRequested: $focusAnswer
        )
        .accessibilityIdentifier("card.answer")
    }

    @ViewBuilder
    private var preview: some View {
        if side == .front {
            CardMarkdownView(markdown: card.prompt.isEmpty ? "*No prompt yet*" : card.prompt, snippet: card.codeSnippet)
        } else {
            CardMarkdownView(markdown: card.answer.isEmpty ? "*No answer yet*" : card.answer)
        }
    }

    // MARK: Code

    @ViewBuilder
    private var codeSection: some View {
        if let snippet = card.snippet {
            VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                HStack(spacing: CodeySpacing.sm) {
                    Picker("Language", selection: snippetBinding(\.language, default: snippet.language)) {
                        ForEach(CodeLanguage.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(CodeyColor.brand)
                    .accessibilityIdentifier("card.language")

                    Spacer(minLength: 0)

                    LimitCounter(
                        count: ModelValidator.lineCount(snippet.source),
                        limit: ModelValidator.Limits.snippetMaxLines,
                        unit: "lines"
                    )

                    Button("Remove code", systemImage: "trash", role: .destructive) {
                        withAnimation(CodeyMotion.snappy) { viewModel.toggleSnippet(cardID: card.id) }
                    }
                    .labelStyle(.iconOnly)
                    // The destructive role tints system red; use the muted
                    // palette danger instead (S9).
                    .foregroundStyle(CodeyColor.danger)
                    .frame(minWidth: 44, minHeight: 44)
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
        } else {
            Button {
                withAnimation(CodeyMotion.snappy) { viewModel.toggleSnippet(cardID: card.id) }
            } label: {
                Label("Add code", systemImage: "plus")
                    .font(.codeyCallout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CodeySpacing.sm + CodeySpacing.xs)
                    .overlay {
                        RoundedRectangle.codey(CodeyRadius.md)
                            .strokeBorder(CodeyColor.separator, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
                    .contentShape(.rect(cornerRadius: CodeyRadius.md))
            }
            .buttonStyle(.plain)
            .foregroundStyle(CodeyColor.brand)
            .accessibilityIdentifier("card.addCode")
        }
    }

    private func snippetBinding<Value>(_ keyPath: WritableKeyPath<SnippetDraft, Value>, default fallback: Value) -> Binding<Value> {
        Binding(
            get: { card.snippet?[keyPath: keyPath] ?? fallback },
            set: { card.snippet?[keyPath: keyPath] = $0 }
        )
    }
}
