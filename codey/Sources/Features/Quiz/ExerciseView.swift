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

    private var hue: CodeyColor.TopicHue { .of(topicID: exercise.topicId) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.md) {
                header

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
                    VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                        Text("Explanation")
                            .font(.codeyHeadline)
                            .foregroundStyle(CodeyColor.textPrimary)
                        Text(Self.inline(exercise.explanation))
                            .font(.codeyBody)
                            .foregroundStyle(CodeyColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(CodeySpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .codeyNote()
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("exercise.explanation")
                    CodeyButton("Try Again", systemImage: "arrow.counterclockwise", kind: .secondary, fullWidth: true) {
                        answers = Array(repeating: "", count: exercise.blanks.count)
                        self.result = nil
                        focusedBlank = 0
                    }
                    .accessibilityIdentifier("exercise.retry")
                } else {
                    CodeyButton("Check", systemImage: "checkmark", kind: .hue(hue), fullWidth: true) {
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

    /// The task on the topic's pastel (S42), like a tile: language and the
    /// first-solve reward as tags, then the prompt.
    private var header: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(spacing: CodeySpacing.xs) {
                Icon("chevron.left.forwardslash.chevron.right", size: 22, relativeTo: .title2)
                Spacer(minLength: 0)
                CodeyChip(exercise.language.displayName, variant: .outline(hue.ink))
                CodeyChip(xp: XPRewards.exerciseBlank * exercise.blanks.count)
            }
            Text(Self.inline(exercise.prompt))
                .font(.codeyCardText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(hue.ink)
        .padding(CodeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hue.soft, in: .codey(CodeyRadius.lg))
        .environment(\.colorScheme, .light)
    }

    /// Inline Markdown (`code`, *emphasis*) as styled text; plain text if
    /// it doesn't parse.
    static func inline(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
    }

    /// One blank on a note: its number, the field, and after Check the
    /// result tag and (if wrong) the accepted answer.
    private func blankField(_ index: Int) -> some View {
        let blank = result?.blanks[index]
        return VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(spacing: CodeySpacing.sm) {
                Text("\(index + 1)")
                    .font(.codeySubheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(hue.fill, in: Circle())
                    .accessibilityHidden(true)
                Text("Blank \(index + 1)")
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
                Spacer(minLength: 0)
                if let blank {
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
                .padding(CodeySpacing.sm + CodeySpacing.xs)
                .background(CodeyColor.codeBackground, in: .codey(CodeyRadius.md))
                .overlay {
                    RoundedRectangle.codey(CodeyRadius.md)
                        .strokeBorder(focusedBlank == index ? hue.fill : .clear, lineWidth: 2)
                }
                .accessibilityIdentifier("exercise.blank.\(index + 1)")
            if let blank, !blank.isPassed {
                HStack(spacing: CodeySpacing.xs) {
                    Text("Answer")
                        .font(.codeyCaption)
                        .foregroundStyle(CodeyColor.textSecondary)
                    ForEach(exercise.blanks[index].accepted, id: \.self) { answer in
                        CodeyChip(answer, variant: .neutral)
                            .font(.codeyCaption.monospaced())
                    }
                }
            }
        }
        .padding(CodeySpacing.md)
        .codeyNote()
    }

    private func summary(_ result: ExerciseResult) -> some View {
        let total = result.blanks.count
        let passed = result.allPassed
        return HStack(spacing: CodeySpacing.sm) {
            Icon(passed ? "checkmark.seal.fill" : "exclamationmark.triangle", size: 24, relativeTo: .title2)
                .foregroundStyle(passed ? CodeyColor.success : CodeyColor.warning)
            Text(passed
                 ? "All \(total) \(total == 1 ? "test" : "tests") passed"
                 : "\(result.passedCount) of \(total) \(total == 1 ? "test" : "tests") passed")
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textPrimary)
            Spacer(minLength: 0)
            if xpPaid > 0 {
                CodeyChip(xp: xpPaid)
            }
        }
        .padding(CodeySpacing.md)
        .codeyNote(fill: passed ? CodeyColor.Soft.success : CodeyColor.Soft.warning, edge: .clear)
        .accessibilityElement(children: .combine)
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
