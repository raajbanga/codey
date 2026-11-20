import SwiftData
import SwiftUI
import os

/// One coding challenge (S45, FR-69 to FR-74): the problem, an editor
/// with starter code, Run (the examples) and Submit (every test, hidden
/// ones too) on the Codey runner, and the results.
///
/// Two layouts, both on paper with the app's edge fades.
///
///     wide (≥ splitWidth)                  compact (phone, iPad portrait)
///     ╭ hero        ╮  ╭ code        ╮     ╭ hero ╮
///     │ description │  │ editor      │     [Description][Code][Result]
///     │ examples ↕  │  ╰─────────────╯     Code tab: editor, then
///     │ hints       │  [Run][Submit](Ask)  [Run][Submit](Ask), then hints
///     ╰─────────────╯  ╭ results ↕   ╮
///
/// An accepted submission swaps the page for the shared session summary
/// (like a drill), with the editorial. The student's code is saved per
/// challenge and language as they type (FR-73).
struct ChallengeView: View {
    enum Tab: Hashable { case description, code, result }

    @State private var challenge: Challenge
    @State private var language: CodeLanguage
    @State private var code: String
    @State private var tab = Tab.description
    @State private var verdict: ChallengeVerdict?
    @State private var runError: String?
    @State private var running: ChallengeRunMode?
    @State private var isAccepted = false
    @State private var xpPaid = 0
    @State private var confirmsReset = false
    @State private var askAI: AskAISession?
    /// Keyboard on screen (§3b, like the deck builder): the page sheds
    /// everything but the code, so the editor isn't squeezed to a sliver.
    @State private var keyboardUp = false
    /// The page's own width: two panes from splitWidth (iPad landscape, Mac).
    @State private var width: CGFloat = 0
    /// The code bento's title row, so the problem pane starts level with
    /// the editor.
    @State private var codeTitleHeight: CGFloat = 0
    @Environment(\.codeyLayout) private var layout

    @Environment(\.modelContext) private var context
    @Environment(BackendFacade.self) private var backend
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    init(challenge: Challenge) {
        let language = Self.preferredLanguage(for: challenge)
        _challenge = State(initialValue: challenge)
        _language = State(initialValue: language)
        _code = State(initialValue: ChallengeDrafts.load(challenge.id, language: language) ?? challenge.starter(for: language))
    }

    private var hue: CodeyColor.TopicHue { .of(topicID: challenge.topicId) }

    var body: some View {
        Group {
            if isAccepted {
                solvedSummary
                    .padding(.horizontal, CodeySpacing.md)
                    .transition(CodeyMotion.popTransition(reduceMotion: reduceMotion))
            } else {
                workspace
            }
        }
        .codeyPaperBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
        .toolbarVisibility(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(isAccepted)
        .sensoryFeedback(trigger: verdict) { _, new in
            guard let new else { return nil }
            return new.isAccepted ? .success : .error
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withCodeyAnimation(reduceMotion: reduceMotion) { keyboardUp = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withCodeyAnimation(reduceMotion: reduceMotion) { keyboardUp = false }
        }
        .onChange(of: code) { _, new in
            ChallengeDrafts.save(new, id: challenge.id, language: language)
        }
        .codeyConfirm(
            "Reset to the starter code?",
            isPresented: $confirmsReset,
            message: "Your \(language.displayName) code for this challenge will be replaced."
        ) {
            [.init("Reset Code", isDestructive: true) { resetCode() }]
        }
    }

    // MARK: Workspace

    private var workspace: some View {
        Group {
            if layout.isRegular && width >= CodeyLayout.splitWidth {
                splitWorkspace
            } else {
                tabbedWorkspace
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    /// Phone and narrow iPad: the usual page with Description / Code / Result
    /// tabs; Run and Submit under the code.
    private var tabbedWorkspace: some View {
        CodeyPage(challenge.title, hero: {
            if !keyboardUp {
                header.transition(.move(edge: .top).combined(with: .opacity))
            }
        }) {
            if !keyboardUp {
                ChoiceChips("Section", selection: $tab, options: [
                    (.description, "Description"), (.code, "Code"), (.result, "Result"),
                ], fills: true)
                .accessibilityIdentifier("challenge.tabs")
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            switch tab {
            case .description: descriptionBentos
            case .code:
                codeBento(editorHeight: 440)
                // Run / Submit live with the code, above the hints; the
                // page then ends in the usual edge fade, no pinned bar.
                if !keyboardUp {
                    actionButtons
                    hintBento
                }
            case .result: resultBentos
            }
        }
        .id(challenge.id)
    }

    /// Wide: two panes. Only the problem scrolls; the code fills the right
    /// pane with Run / Submit under it, and the results share that pane
    /// once there are any.
    ///
    ///     ╭ hero        ╮  ╭ code              ╮
    ///     │ description │  │                   │
    ///     │ examples  ↕ │  ╰───────────────────╯
    ///     │ hints       │  [Run] [Submit]  (Ask)
    ///     ╰─────────────╯  ╭ results ↕         ╮
    private var splitWorkspace: some View {
        HStack(alignment: .top, spacing: layout.gridGap) {
            ScrollView {
                VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                    header
                    descriptionBentos
                    hintBento
                }
                .padding(.bottom, layout.pageMargin)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            // The hero's top lines up with the code bento's, under its
            // title row.
            .contentMargins(.top, codeTitleHeight + CodeySpacing.sm, for: .scrollContent)

            VStack(alignment: .leading, spacing: CodeySpacing.md) {
                codeBento(editorHeight: nil)
                actionButtons
                if verdict != nil || runError != nil || running != nil {
                    ScrollView {
                        VStack(alignment: .leading, spacing: CodeySpacing.md) { resultBentos }
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: .infinity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, layout.pageMargin)
        // CodeyPage's edges: inset past the clock and home indicator, with
        // the same soft blur, so neither column is cut off sharply.
        .codeyTabPage()
        .id(challenge.id)
        // What CodeyPage gives every page: a title for VoiceOver, swipe back.
        .navigationTitle(challenge.title)
        .background { SwipeBackEnabler().frame(width: 0, height: 0).accessibilityHidden(true) }
        .accessibilityAction(.escape) { dismiss() }
    }

    /// Run and Submit; Ask AI beside them, bottom right as on a drill.
    private var actionButtons: some View {
        HStack(spacing: CodeySpacing.sm) {
            CodeyButton(running == .run ? "Running…" : "Run", systemImage: "play", kind: .secondary, fullWidth: true, slim: true) {
                run(.run)
            }
            .disabled(running != nil)
            .accessibilityIdentifier("challenge.run")
            CodeyButton(running == .submit ? "Judging…" : "Submit", systemImage: "paperplane", kind: .hue(hue), fullWidth: true, slim: true) {
                run(.submit)
            }
            .disabled(running != nil)
            .accessibilityIdentifier("challenge.submit")
            if let client = AskAI.client {
                CircleIconButton(systemImage: "ask.ai", label: "Ask Codey", kind: .soft) {
                    let context = AskAIContext.challenge(challenge, language: language, code: code)
                    askAI = AskAISession.reusing(askAI, for: context, client: client)
                    router.askAI = askAI
                }
                .accessibilityHint("Opens a tutor that explains the idea without writing your code")
                .accessibilityIdentifier("askAI.open")
            }
        }
    }

    /// The challenge on its topic's pastel: tier and first-solve reward.
    private var header: some View {
        HeroCard(
            title: challenge.title,
            icon: "terminal",
            hue: hue,
            attributedSubtitle: AttributedString(solvedBefore ? "Solved before" : "Write the whole function")
        ) {
            CodeyChip(tier: challenge.difficulty)
            CodeyChip(xp: XPRewards.challengeReward(challenge.difficulty))
        }
    }

    // MARK: Description

    @ViewBuilder private var descriptionBentos: some View {
        CardMarkdownView(markdown: challenge.statement)
            .codeyCard()
            .accessibilityIdentifier("challenge.statement")

        ForEach(challenge.examples.indices, id: \.self) { index in
            exampleCard(index)
        }

        if !challenge.constraints.isEmpty {
            VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                Text("Constraints")
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
                ForEach(challenge.constraints, id: \.self) { constraint in
                    Text("• \(ExerciseView.inline(constraint))")
                }
                .font(.codeySubheadline)
                .foregroundStyle(CodeyColor.textPrimary)
            }
            .codeyCard()
            .accessibilityElement(children: .combine)
        }

    }

    @ViewBuilder private var hintBento: some View {
        if !challenge.hints.isEmpty {
            HintBento(hints: challenge.hints, hue: hue, idPrefix: "challenge")
        }
    }

    private func exampleCard(_ index: Int) -> some View {
        let example = challenge.examples[index]
        return VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            Text("Example \(index + 1)")
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textPrimary)
            labeledCode("Input", example.input)
            labeledCode("Output", example.output)
            if let explanation = example.explanation, !explanation.isEmpty {
                Text(ExerciseView.inline(explanation))
                    .font(.codeySubheadline)
                    .foregroundStyle(CodeyColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .codeyCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: Code

    /// The editor is the bento itself (no card around a code box), under
    /// a title row with the language tag and ⋯, like a BentoSection. While
    /// typing it fills the visible page.
    /// `editorHeight` nil: fill the pane (two-pane layout).
    private func codeBento(editorHeight: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(spacing: CodeySpacing.sm) {
                SectionTitle("Code")
                Spacer(minLength: 0)
                // The same tag as the deck builder's code language.
                CodeyMenu(.value(language.displayName, systemImage: "chevron.left.forwardslash.chevron.right")) {
                    CodeyMenuItem.choices(challenge.languages, selection: languageBinding, title: \.displayName)
                }
                .accessibilityLabel("Language: \(language.displayName)")
                .accessibilityIdentifier("challenge.language")
                CircleIconButton(systemImage: "arrow.counterclockwise", label: "Reset to starter code", kind: .soft, compact: true) {
                    confirmsReset = true
                }
                .accessibilityIdentifier("challenge.reset")
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { codeTitleHeight = $0 }
            Group {
                let editor = CodeEditorView(text: $code, language: language, textStyle: .body)
                    .padding(.vertical, CodeySpacing.xs)
                // The branch is fixed for a layout; keyboardUp only changes
                // values, so the text view is never rebuilt mid-typing.
                if let editorHeight {
                    editor.containerRelativeFrame(.vertical, alignment: .top) { visible, _ in
                        // Typing: the visible page less the title row (44) and gaps.
                        keyboardUp ? max(visible - 44 - CodeySpacing.sm - CodeySpacing.lg, 200) : editorHeight
                    }
                } else {
                    editor.frame(maxHeight: .infinity)
                }
            }
                .background(CodeyColor.codeBackground)
                .clipShape(.codey(CodeyRadius.lg))
                .codeyNote(fill: CodeyColor.codeBackground)
                .accessibilityLabel("\(language.displayName) code editor")
                .accessibilityIdentifier("challenge.editor")
        }
    }

    /// Changing language keeps both drafts: each language has its own.
    private var languageBinding: Binding<CodeLanguage> {
        Binding {
            language
        } set: { new in
            guard new != language else { return }
            ChallengeDrafts.save(code, id: challenge.id, language: language)
            language = new
            code = ChallengeDrafts.load(challenge.id, language: new) ?? challenge.starter(for: new)
        }
    }

    // MARK: Results

    @ViewBuilder private var resultBentos: some View {
        if running != nil {
            HStack(spacing: CodeySpacing.sm) {
                ProgressView()
                Text(running == .submit ? "Running every test…" : "Running the examples…")
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .codeyCard()
            .accessibilityIdentifier("challenge.running")
        } else if let runError {
            VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                Label("Couldn't run your code", icon: "wifi.exclamationmark")
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
                Text(runError)
                    .font(.codeySubheadline)
                    .foregroundStyle(CodeyColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(CodeySpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .codeyNote(fill: CodeyColor.Soft.warning, edge: .clear)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("challenge.runError")
        } else if let verdict {
            verdictCard(verdict)
            if !verdict.compileOutput.isEmpty {
                outputCard("Compiler", verdict.compileOutput)
            }
            ForEach(verdict.tests.filter { !$0.hidden }) { test in
                TestCaseCard(test: test)
            }
            if verdict.tests.contains(where: \.hidden) {
                hiddenTestsCard(verdict.tests.filter(\.hidden))
            }
            if !verdict.stdout.isEmpty {
                outputCard("Your output", verdict.stdout)
            }
            if !verdict.stderr.isEmpty, verdict.compileOutput.isEmpty {
                outputCard("Errors", verdict.stderr)
            }
        } else {
            Text("Run your code to see the results here.")
                .font(.codeySubheadline)
                .foregroundStyle(CodeyColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .codeyCard()
        }
    }

    private func verdictCard(_ verdict: ChallengeVerdict) -> some View {
        let style = Self.style(verdict.status)
        return HStack(spacing: CodeySpacing.sm) {
            Icon(style.symbol, size: 24, relativeTo: .title2)
                .foregroundStyle(style.color)
            VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                Text(style.title)
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
                Text("\(verdict.passedCount) of \(verdict.total) \(verdict.mode == .run ? "examples" : "tests") passed"
                     + (verdict.elapsedMs.map { " · \($0) ms" } ?? ""))
                    .font(.codeySubheadline.monospacedDigit())
                    .foregroundStyle(CodeyColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(CodeySpacing.md)
        .codeyNote(fill: verdict.isAccepted ? CodeyColor.Soft.success : CodeyColor.Soft.warning, edge: .clear)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("challenge.verdict")
    }

    /// Hidden tests: pass/fail dots only (their inputs never reach the app).
    private func hiddenTestsCard(_ tests: [ChallengeVerdict.Test]) -> some View {
        let passed = tests.filter { $0.status == .passed }.count
        return VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            Text("Hidden tests: \(passed) of \(tests.count) passed")
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 28), spacing: CodeySpacing.xs)], alignment: .leading, spacing: CodeySpacing.xs) {
                ForEach(tests) { test in
                    Icon(test.status == .passed ? "checkmark.circle.fill" : test.status == .notRun ? "minus.circle" : "xmark.circle.fill",
                         size: 22, relativeTo: .body)
                        .foregroundStyle(test.status == .passed ? CodeyColor.success : test.status == .notRun ? CodeyColor.textSecondary : CodeyColor.danger)
                }
            }
            if let error = tests.first(where: { $0.error != nil })?.error {
                Text(error)
                    .font(.codeyCaption.monospaced())
                    .foregroundStyle(CodeyColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .codeyCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("challenge.hidden")
    }

    private func outputCard(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            Text(title)
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textPrimary)
            ScrollView(.horizontal) {
                Text(text)
                    .font(.codeyCode)
                    .foregroundStyle(CodeyColor.textPrimary)
                    .textSelection(.enabled)
                    .padding(CodeySpacing.sm)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CodeyColor.codeBackground, in: .codey(CodeyRadius.md))
        }
        .codeyCard()
    }

    private func labeledCode(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
            Text(label)
                .font(.codeyCaption)
                .foregroundStyle(CodeyColor.textSecondary)
            Text(value)
                .font(.codeyCode)
                .foregroundStyle(CodeyColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CodeySpacing.sm)
                .background(CodeyColor.codeBackground, in: .codey(CodeyRadius.md))
        }
    }

    static func style(_ status: ChallengeVerdict.Status) -> (title: String, symbol: String, color: Color) {
        switch status {
        case .accepted: ("Accepted", "checkmark.seal.fill", CodeyColor.success)
        case .wrongAnswer: ("Wrong Answer", "xmark.octagon", CodeyColor.danger)
        case .compileError: ("Compile Error", "hammer", CodeyColor.warning)
        case .runtimeError: ("Runtime Error", "exclamationmark.triangle", CodeyColor.warning)
        case .timeLimit: ("Time Limit Exceeded", "timer", CodeyColor.warning)
        }
    }

    // MARK: Running

    private func run(_ mode: ChallengeRunMode) {
        guard running == nil else { return }
        let request = ChallengeRunRequest(challengeId: challenge.id, language: language, code: code, mode: mode)
        let runner = ChallengeRunnerFactory.make(remote: backend.remote)
        withCodeyAnimation(reduceMotion: reduceMotion) {
            running = mode
            runError = nil
            tab = .result
        }
        Task {
            var newVerdict: ChallengeVerdict?
            var newError: String?
            if let runner {
                do {
                    newVerdict = try await runner.run(request)
                } catch let error as ChallengeRunError {
                    newError = error.localizedDescription
                } catch {
                    newError = "Couldn't reach the code runner. Try again."
                    Logger.quiz.error("Challenge run failed: \(String(describing: error))")
                }
            } else {
                newError = ChallengeRunError.notConfigured.localizedDescription
            }
            let accepted = newVerdict?.isAccepted == true && mode == .submit
            let paid = accepted ? payXP() : 0
            withCodeyAnimation(reduceMotion: reduceMotion) {
                running = nil
                verdict = newVerdict ?? verdict
                runError = newError
                if newError != nil { verdict = nil }
                xpPaid = paid
                isAccepted = accepted
            }
        }
    }

    private var solvedBefore: Bool {
        profiles.first?.solvedExerciseIds.contains(challenge.id) == true
    }

    /// The first accepted submission pays by difficulty (XPRewards).
    private func payXP() -> Int {
        let profile = DataSeeder.ensureProfile(context: context)
        let paid = XPRewards.solveChallenge(id: challenge.id, difficulty: challenge.difficulty, profile: profile, weeklyXP: WeeklyXPStore(), now: .now)
        do {
            try BadgeEvaluator.award(context: context, now: .now)
            try context.save()
        } catch {
            Logger.quiz.error("Saving challenge XP failed: \(String(describing: error))")
        }
        return paid
    }

    private func resetCode() {
        ChallengeDrafts.remove(challenge.id, language: language)
        code = challenge.starter(for: language)
    }

    // MARK: Solved

    private var solvedSummary: some View {
        SessionSummary(
            title: "Accepted!",
            subtitle: challenge.title,
            hue: hue,
            xpEarned: xpPaid,
            stats: [
                SummaryStat(value: verdict?.total ?? 0, label: "Tests passed", systemImage: "checkmark.circle.fill", tint: CodeyColor.success),
                SummaryStat(value: verdict?.elapsedMs ?? 0, label: "Runtime", suffix: "ms", systemImage: "timer"),
            ],
            againTitle: "Next Challenge",
            againSystemImage: "arrow.right",
            againID: "challenge.next",
            doneID: "challenge.done",
            again: nextChallenge.map { next in { open(next) } },
            done: { dismiss() }
        ) {
            if !challenge.editorial.isEmpty {
                SummaryNote(title: "How it works", markdown: challenge.editorial)
                    .accessibilityIdentifier("challenge.editorial")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("challenge.solved")
    }

    private var nextChallenge: Challenge? {
        ChallengeCatalog.shared.next(after: challenge, solved: Set(profiles.first?.solvedExerciseIds ?? []))
    }

    private func open(_ next: Challenge) {
        let nextLanguage = challenge.languages.contains(language) && next.languages.contains(language) ? language : Self.preferredLanguage(for: next)
        withCodeyAnimation(reduceMotion: reduceMotion) {
            challenge = next
            language = nextLanguage
            code = ChallengeDrafts.load(next.id, language: nextLanguage) ?? next.starter(for: nextLanguage)
            verdict = nil
            runError = nil
            xpPaid = 0
            isAccepted = false
            tab = .description
        }
        askAI = nil
    }

    /// Python first: the shortest starter and the one most students know.
    static func preferredLanguage(for challenge: Challenge) -> CodeLanguage {
        challenge.languages.contains(.python) ? .python : challenge.languages.first ?? .python
    }
}

/// One example test's result (FR-71): pass/fail chip, input, expected and
/// actual output, or the error it raised. Symbol and word, not color
/// alone (NFR-12).
struct TestCaseCard: View {
    let test: ChallengeVerdict.Test

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(spacing: CodeySpacing.sm) {
                Text("Case \(test.ordinal)")
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
                Spacer(minLength: 0)
                TestResultChip(status: test.status)
            }
            if let input = test.input { row("Input", input) }
            if let expected = test.expected { row("Expected", expected.description) }
            if let actual = test.actual { row("Your output", actual.description, highlight: test.status == .failed) }
            if let error = test.error {
                Text(error)
                    .font(.codeyCaption.monospaced())
                    .foregroundStyle(CodeyColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .codeyCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("challenge.case.\(test.ordinal)")
    }

    private func row(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
            Text(label)
                .font(.codeyCaption)
                .foregroundStyle(CodeyColor.textSecondary)
            Text(value)
                .font(.codeyCode)
                .foregroundStyle(highlight ? CodeyColor.danger : CodeyColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CodeySpacing.sm)
                .background(CodeyColor.codeBackground, in: .codey(CodeyRadius.md))
        }
    }
}

struct TestResultChip: View {
    let status: ChallengeVerdict.Test.Status

    var body: some View {
        switch status {
        case .passed: CodeyChip("Passed", systemImage: "checkmark", variant: .success)
        case .failed: CodeyChip("Failed", systemImage: "xmark", variant: .danger)
        case .error: CodeyChip("Error", systemImage: "exclamationmark", variant: .danger)
        case .notRun: CodeyChip("Not run", systemImage: "minus", variant: .neutral)
        }
    }
}
