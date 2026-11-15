import SwiftUI
import os

/// One code-completion exercise (FR-39 to FR-41): the highlighted snippet
/// with numbered blanks, one monospaced field per blank, and Check, which
/// runs each blank's test case and shows pass or fail per blank plus the
/// explanation. The first full solve pays XP (S41); nothing else is saved.
struct ExerciseView: View {
    let exercise: Exercise

    @State private var answers: [String]
    @State private var result: ExerciseResult?
    /// XP the last Check paid (S41): 0 if already solved before.
    @State private var xpPaid = 0
    @Environment(\.modelContext) private var context
    @FocusState private var focusedBlank: Int?
    /// Ask AI (S39): lives as long as this exercise is on screen (FR-68).
    @State private var askAI: AskAISession?
    @Environment(Router.self) private var router

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
                        let checked = ExerciseValidator.check(answers, for: exercise)
                        result = checked
                        xpPaid = checked.allPassed ? payXP() : 0
                    }
                    .accessibilityIdentifier("exercise.submit")
                }
            }
            .padding(CodeySpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .codeyPaperBackground()
        .codeyPageTitle(exercise.title)
        .toolbar {
            if let client = AskAI.client {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        focusedBlank = nil
                        askAI = AskAISession.reusing(askAI, for: .exercise(exercise), client: client)
                        router.askAI = askAI
                    } label: {
                        Label("Ask AI", icon: "ask.ai")
                    }
                    .accessibilityHint("Opens a tutor that explains the idea without giving the answer")
                    .accessibilityIdentifier("askAI.open")
                }
            }
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
            HStack {
            Label(
                result.allPassed
                    ? "All \(total) \(total == 1 ? "test" : "tests") passed"
                    : "\(result.passedCount) of \(total) tests passed",
                systemImage: result.allPassed ? "checkmark.seal.fill" : "exclamationmark.circle"
            )
            .font(.codeyHeadline)
            .foregroundStyle(CodeyColor.textPrimary)
                Spacer(minLength: 0)
                if xpPaid > 0 {
                    CodeyChip(xp: xpPaid)
                }
            }
        }
        .accessibilityIdentifier("exercise.summary")
    }

    /// The first full solve pays 10 XP per blank (XPRewards).
    private func payXP() -> Int {
        let profile = DataSeeder.ensureProfile(context: context)
        let paid = XPRewards.solveExercise(id: exercise.id, blanks: exercise.blanks.count, profile: profile, weeklyXP: WeeklyXPStore(), now: .now)
        do {
            try BadgeEvaluator.award(context: context, now: .now)
            try context.save()
        } catch {
            Logger.quiz.error("Saving exercise XP failed: \(String(describing: error))")
        }
        return paid
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
    .environment(Router())
}
