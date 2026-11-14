import SwiftUI

/// One code-completion exercise (FR-39 to FR-41): the highlighted snippet
/// with numbered blanks, one monospaced field per blank, and Check, which
/// runs each blank's test case and shows pass or fail per blank plus the
/// explanation. Nothing is saved (S31).
struct ExerciseView: View {
    let exercise: Exercise

    @State private var answers: [String]
    @State private var result: ExerciseResult?
    @FocusState private var focusedBlank: Int?
    /// Ask AI (S39): lives as long as this exercise is on screen (FR-68).
    @State private var askAI: AskAISession?
    @State private var presentedAskAI: AskAISession?

    init(exercise: Exercise) {
        self.exercise = exercise
        _answers = State(initialValue: Array(repeating: "", count: exercise.blanks.count))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.md) {
                Text(exercise.prompt)
                    .font(.codeyCardText)
                    .foregroundStyle(CodeyColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                // Not selectable: the header's copy button covers copying, and
                // a selectable text view has no accessibility label.
                CardMarkdownView(
                    markdown: "",
                    snippet: CodeSnippet(language: exercise.language, source: exercise.displayCode),
                    isSelectable: false
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(exercise.language.displayName) code with \(exercise.blanks.count) numbered blanks")

                ForEach(exercise.blanks.indices, id: \.self) { index in
                    blankField(index)
                }

                if let result {
                    summary(result)
                    CodeyCard {
                        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                            Text("Explanation")
                                .font(.codeyHeadline)
                                .foregroundStyle(CodeyColor.textPrimary)
                            CardMarkdownView(markdown: exercise.explanation)
                        }
                    }
                    .accessibilityIdentifier("exercise.explanation")
                    CodeyButton("Try Again", systemImage: "arrow.counterclockwise", kind: .secondary, fullWidth: true) {
                        answers = Array(repeating: "", count: exercise.blanks.count)
                        self.result = nil
                        focusedBlank = 0
                    }
                    .accessibilityIdentifier("exercise.retry")
                } else {
                    CodeyButton("Check", systemImage: "checkmark", fullWidth: true) {
                        focusedBlank = nil
                        result = ExerciseValidator.check(answers, for: exercise)
                    }
                    .accessibilityIdentifier("exercise.submit")
                }
            }
            .padding(CodeySpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .codeyPaperBackground()
        .navigationTitle(exercise.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let client = AskAI.client {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ask AI", systemImage: "sparkles") {
                        focusedBlank = nil
                        askAI = AskAISession.reusing(askAI, for: .exercise(exercise), client: client)
                        presentedAskAI = askAI
                    }
                    .accessibilityHint("Opens a tutor that explains the idea without giving the answer")
                    .accessibilityIdentifier("askAI.open")
                }
            }
        }
        .sheet(item: $presentedAskAI) { session in
            AskAIChatView(session: session)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(trigger: result) { _, new in
            guard let new else { return nil }
            return new.allPassed ? .success : .error
        }
    }

    private func blankField(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            HStack {
                Text("Blank ⟦\(index + 1)⟧")
                    .font(.codeySubheadline.weight(.semibold))
                    .foregroundStyle(CodeyColor.textSecondary)
                Spacer(minLength: 0)
                if let blank = result?.blanks[index] {
                    BlankResultChip(result: blank)
                        .accessibilityIdentifier("exercise.result.\(index + 1)")
                }
            }
            TextField("Answer for blank \(index + 1)", text: $answers[index])
                .font(.codeyCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(index == exercise.blanks.count - 1 ? .done : .next)
                .focused($focusedBlank, equals: index)
                .onSubmit { focusedBlank = index + 1 < exercise.blanks.count ? index + 1 : nil }
                .disabled(result != nil)
                .padding(CodeySpacing.sm)
                .background(CodeyColor.codeBackground, in: .rect(cornerRadius: CodeyRadius.sm))
                .accessibilityIdentifier("exercise.blank.\(index + 1)")
            if let blank = result?.blanks[index], !blank.isPassed {
                Text("Accepted: \(exercise.blanks[index].accepted.joined(separator: "  or  "))")
                    .font(.codeyCaption.monospaced())
                    .foregroundStyle(CodeyColor.textSecondary)
            }
        }
    }

    private func summary(_ result: ExerciseResult) -> some View {
        let total = result.blanks.count
        return CodeyCard(tint: result.allPassed ? CodeyColor.Soft.success : CodeyColor.Soft.warning) {
            Label(
                result.allPassed
                    ? "All \(total) \(total == 1 ? "test" : "tests") passed"
                    : "\(result.passedCount) of \(total) tests passed",
                systemImage: result.allPassed ? "checkmark.seal.fill" : "exclamationmark.circle"
            )
            .font(.codeyHeadline)
            .foregroundStyle(CodeyColor.textPrimary)
        }
        .accessibilityIdentifier("exercise.summary")
    }
}

/// Pass/fail chip for one blank's test case (FR-41). Symbol and word, not
/// color alone (NFR-12).
private struct BlankResultChip: View {
    let result: BlankResult

    var body: some View {
        switch result {
        case .passed: CodeyChip("Passed", systemImage: "checkmark", variant: .success)
        case .failed: CodeyChip("Failed", systemImage: "xmark", variant: .danger)
        case .empty: CodeyChip("No answer", systemImage: "minus", variant: .danger)
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseView(exercise: (try? ExerciseLoader.load())!.first!)
    }
}
