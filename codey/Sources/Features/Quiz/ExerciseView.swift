import SwiftData
import SwiftUI
import os

/// One code-completion exercise (FR-39 to FR-41): the highlighted snippet
/// with numbered blanks, one monospaced field per blank, and Check, which
/// runs each blank's test case. The first full solve pays XP (S41);
/// nothing else is saved.
///
/// §3c: a full pass swaps the page for the shared session summary (Solved,
/// XP, explanation, Next Challenge / Done), like the end of a quiz. A miss
/// keeps the per-blank results with Try Again and Try Another. Next and
/// Another load the picked exercise in place (ExercisePicker).
struct ExerciseView: View {
    @State private var exercise: Exercise

    @State private var answers: [String]
    @State private var result: ExerciseResult?
    /// XP the last Check paid (S41): 0 if already solved before.
    @State private var xpPaid = 0
    @Environment(\.modelContext) private var context
    @FocusState private var focusedBlank: Int?
    /// Ask AI (S39): lives as long as this exercise is on screen (FR-68).
    @State private var askAI: AskAISession?
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 112

    init(exercise: Exercise) {
        _exercise = State(initialValue: exercise)
        _answers = State(initialValue: Array(repeating: "", count: exercise.blanks.count))
    }

    private var hue: CodeyColor.TopicHue { .of(topicID: exercise.topicId) }

    var body: some View {
        Group {
            if let result, result.allPassed {
                solvedSummary
                    .padding(.horizontal, CodeySpacing.md)
                    .transition(CodeyMotion.popTransition(reduceMotion: reduceMotion))
            } else {
                workspace
            }
        }
        .codeyPaperBackground()
        .sensoryFeedback(trigger: result) { _, new in
            guard let new else { return nil }
            return new.allPassed ? .success : .error
        }
    }

    /// The task, the code, a field per blank, then Check; after a miss, the
    /// per-blank results and Try Again / Try Another.
    private var workspace: some View {
        CodeyPage(exercise.title) {
            if let client = AskAI.client {
                CircleIconButton(systemImage: "ask.ai", label: "Ask Codey", kind: .soft) {
                    focusedBlank = nil
                    askAI = AskAISession.reusing(askAI, for: .exercise(exercise), client: client)
                    router.askAI = askAI
                }
                .accessibilityHint("Opens a tutor that explains the idea without giving the answer")
                .accessibilityIdentifier("askAI.open")
            }
        } hero: {
            header
        } content: {
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
                explanation
                HStack(spacing: CodeySpacing.sm) {
                    CodeyButton("Try Again", systemImage: "arrow.counterclockwise", kind: .hue(hue), fullWidth: true) {
                        retry()
                    }
                    .accessibilityIdentifier("exercise.retry")
                    if let next = nextExercise {
                        CodeyButton("Try Another", systemImage: "shuffle", kind: .secondary, fullWidth: true) {
                            open(next)
                        }
                        .accessibilityIdentifier("exercise.another")
                    }
                }
            } else {
                CodeyButton("Check", systemImage: "checkmark", kind: .hue(hue), fullWidth: true) {
                    focusedBlank = nil
                    let checked = ExerciseValidator.check(answers, for: exercise)
                    let paid = checked.allPassed ? payXP() : 0
                    withCodeyAnimation(reduceMotion: reduceMotion) {
                        xpPaid = paid
                        result = checked
                    }
                }
                .accessibilityIdentifier("exercise.submit")
            }
        }
        // A new exercise starts at the top, not where the last one was left.
        .id(exercise.id)
    }

    /// The win screen: the same summary as a quiz or study session.
    private var solvedSummary: some View {
        let total = exercise.blanks.count
        return SessionSummary(
            title: "Solved!",
            subtitle: "All \(total) \(total == 1 ? "test" : "tests") passed",
            xpEarned: xpPaid > 0 ? xpPaid : nil,
            againTitle: "Next Challenge",
            againSystemImage: "arrow.right",
            againID: "exercise.next",
            doneID: "exercise.done",
            again: nextExercise.map { next in { open(next) } },
            done: { dismiss() }
        ) {
            IconTile(
                systemName: "checkmark.seal.fill", size: heroSize, radius: CodeyRadius.xl,
                ink: CodeyColor.success, tile: CodeyColor.Soft.success
            )
        } details: {
            if xpPaid == 0 {
                // Said, not hidden: otherwise a repeat solve looks broken.
                Text("Already solved, so no XP this time. XP is paid on the first solve.")
                    .font(.codeySubheadline)
                    .foregroundStyle(CodeyColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            explanation
        }
        .accessibilityIdentifier("exercise.solved")
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            Text("Explanation")
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textPrimary)
            Text(Self.inline(exercise.explanation))
                .font(.codeyBody)
                .foregroundStyle(CodeyColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .codeyCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("exercise.explanation")
    }

    // MARK: Moving on

    /// What Next Challenge / Try Another opens; nil hides them.
    private var nextExercise: Exercise? {
        ExercisePicker.next(
            after: exercise,
            in: ExerciseCatalog.shared.all,
            solved: Set(profiles.first?.solvedExerciseIds ?? [])
        )
    }

    private func retry() {
        withCodeyAnimation(reduceMotion: reduceMotion) {
            answers = Array(repeating: "", count: exercise.blanks.count)
            result = nil
            xpPaid = 0
        }
        focusedBlank = 0
    }

    /// Loads `next` in place: fresh answers, and a fresh Ask AI chat, since
    /// the old one was about the other exercise.
    private func open(_ next: Exercise) {
        withCodeyAnimation(reduceMotion: reduceMotion) {
            exercise = next
            answers = Array(repeating: "", count: next.blanks.count)
            result = nil
            xpPaid = 0
        }
        askAI = nil
        focusedBlank = nil
    }

    /// The exercise on its topic's pastel (S42): language and first-solve
    /// reward as tags, the title, then the task.
    private var header: some View {
        HeroCard(
            title: exercise.title,
            icon: "chevron.left.forwardslash.chevron.right",
            hue: hue,
            attributedSubtitle: Self.inline(exercise.prompt)
        ) {
            CodeyChip(exercise.language.displayName, variant: .outline(hue.ink))
            CodeyChip(xp: XPRewards.exerciseBlank * exercise.blanks.count)
        }
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
                    .foregroundStyle(hue.onFill)
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
        .codeyCard()
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
