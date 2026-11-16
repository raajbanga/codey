import SwiftUI

/// Focus-mode quiz (D8). Presented as a .fullScreenCover.
///
///     ✕  ▮▮▮▯▯▯▯▯▯▯   🔥 3   1,240 XP
///     ╭ ◇ Medium · Review ─ prompt ╮
///     (A) (B) (C) (D)
///     ╭ explanation ╮      [ Next ]  ← pinned bar (codeyBar)
struct QuizModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var viewModel: QuizViewModel
    @State private var toast: XPToast?
    /// Ask AI (S39): the chat for the current question, and whether it is open.
    @State private var askAI: AskAISession?
    @State private var presentedAskAI: AskAISession?

    /// Build `viewModel` in a `ViewModelHost`: its init starts the quiz.
    init(viewModel: QuizViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.questions.isEmpty {
                EmptyStateView(
                    systemImage: "questionmark.bubble",
                    title: "No questions available",
                    message: "Nothing in this topic is ready to quiz right now.",
                    actionTitle: "Done",
                    action: { dismiss() }
                )
                .frame(maxHeight: .infinity)
            } else if viewModel.isFinished {
                // No top bar: Done closes (Nov 15).
                QuizSummaryView(viewModel: viewModel) { dismiss() }
                    .padding(.horizontal, CodeySpacing.md)
            } else if let question = viewModel.currentQuestion {
                questionView(question)
                    .codeyBar(.top) { topBar }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .codeyPaperBackground()
        .xpToast($toast)
        .badgeBanner()
        .onChange(of: viewModel.levelUpToast) { _, level in
            guard let level else { return }
            withCodeyAnimation(CodeyMotion.pop, reduceMotion: reduceMotion) { toast = .level(level) }
            viewModel.levelUpToast = nil
        }
        .onChange(of: viewModel.bonusToast) { _, bonus in
            guard let bonus else { return }
            withCodeyAnimation(CodeyMotion.pop, reduceMotion: reduceMotion) { toast = .bonus(bonus) }
            viewModel.bonusToast = nil
        }
        .floatingPanel(item: $presentedAskAI, fillsHeight: true) { session in
            AskAIChatView(session: session)
        }
    }

    /// Reuses the chat while the question stays the same; a new question
    /// starts a new one (FR-68).
    private func openAskAI(_ question: Question, client: any AskAIClient) {
        let context = AskAIContext.quiz(
            id: question.id, topic: viewModel.topic.title, difficulty: question.difficulty,
            prompt: question.prompt, options: question.options, correctIndex: question.correctOptionIndex
        )
        askAI = AskAISession.reusing(askAI, for: context, client: client)
        presentedAskAI = askAI
    }

    // MARK: Top bar

    private var topBar: some View {
        SessionTopBar(
            closeLabel: "Close quiz",
            closeID: "quiz.close",
            close: { dismiss() }
        ) {
            SessionProgress(
                done: viewModel.results.compactMap { $0.map { $0 ? CodeyColor.success : CodeyColor.danger } },
                total: viewModel.results.count,
                accessibilityLabel: "Question \(min(viewModel.index + 1, viewModel.results.count)) of \(viewModel.results.count)",
                accessibilityValue: "\(viewModel.results.filter { $0 == true }.count) correct so far"
            )
        } trailing: {
            if !viewModel.isPractice {
                // XP earned this quiz (S41 mockup).
                SessionXP(amount: viewModel.xpEarned)
                    .accessibilityIdentifier("quiz.xp")
            }
            if let client = AskAI.client, let question = viewModel.currentQuestion {
                AskAIButton { openAskAI(question, client: client) }
            }
        }
        .padding(.horizontal, CodeySpacing.md)
        .codeyAnimation(CodeyMotion.snappy, value: viewModel.streak)
    }

    // MARK: Question

    /// The question card with the answers as one tight block right under it;
    /// a long question scrolls.
    private func questionView(_ question: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.md) {
                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        HStack(spacing: CodeySpacing.xs) {
                            // The tier and what it pays, as on its Play tile (S41).
                            CodeyChip(tier: question.difficulty)
                            if viewModel.isPractice {
                                CodeyChip("Practice", variant: .neutral)
                            } else {
                                CodeyChip(xp: XPPolicy.base(question.difficulty))
                            }
                            if viewModel.reviewIDs.contains(question.id) {
                                CodeyChip("Review", systemImage: "arrow.counterclockwise", variant: .brand)
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue("Question \(viewModel.index + 1) of \(viewModel.questions.count)")
                        CardMarkdownView(markdown: question.prompt, font: .codeyCardText)
                    }
                }

                answers(question)
                    .padding(.top, CodeySpacing.sm)

                if !viewModel.hasAnswered, !viewModel.isPractice, viewModel.streak >= 1 {
                    Text("Streak \(viewModel.streak): next right answer +\(XPPolicy.xpForCorrectAnswer(tier: question.difficulty, streakAfterIncrement: viewModel.streak + 1)) XP")
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("quiz.streakHint")
                }

                if let feedback = viewModel.feedback {
                    explanation(question, feedback: feedback)
                        .transition(.opacity)
                }
            }
            .padding(CodeySpacing.md)
        }
        .id(question.id)
        .codeyBar(.bottom) {
            if viewModel.hasAnswered {
                CodeyButton(
                    viewModel.isLastQuestion ? "See Results" : "Next",
                    systemImage: viewModel.isLastQuestion ? "flag.checkered" : "arrow.right",
                    kind: .primary,
                    fullWidth: true
                ) {
                    // Instant: an animated swap cross-faded the two
                    // questions over each other (Nov 15).
                    viewModel.next()
                }
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityIdentifier("quiz.next")
                .padding(.horizontal, CodeySpacing.md)
                .padding(.bottom, CodeySpacing.sm)
                .transition(.opacity)
            }
        }
    }

    /// Short answers as a 2×2 grid of big tiles (S41 mockup); long ones
    /// (or big text) as full-width rows so they wrap.
    @ViewBuilder
    private func answers(_ question: Question) -> some View {
        let grid = question.options.count == 4
            && question.options.allSatisfy { $0.count <= 24 && !$0.contains("\n") }
            && !typeSize.isAccessibilitySize
        if grid {
            Grid(horizontalSpacing: CodeySpacing.sm, verticalSpacing: CodeySpacing.sm) {
                ForEach(0..<2, id: \.self) { row in
                    GridRow {
                        ForEach(row * 2..<row * 2 + 2, id: \.self) { index in
                            answerOption(index, question.options[index], question: question, asTile: true)
                        }
                    }
                }
            }
            // Rows hug their tiles; without this the grid shares out the
            // page's spare height and the rows drift apart.
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(spacing: CodeySpacing.sm) {
                ForEach(question.options.indices, id: \.self) { index in
                    answerOption(index, question.options[index], question: question, asTile: false)
                }
            }
        }
    }

    private func answerOption(_ index: Int, _ title: String, question: Question, asTile: Bool) -> some View {
        AnswerOptionRow(
            index: index,
            title: title,
            state: optionState(index, question: question),
            isLocked: viewModel.hasAnswered,
            asTile: asTile
        ) {
            withCodeyAnimation(reduceMotion: reduceMotion) { viewModel.select(index) }
        }
        // Tiles in one grid row match heights; the grid itself is fixedSize,
        // so this never pulls in extra page height.
        .frame(maxHeight: asTile ? .infinity : nil)
        .accessibilityIdentifier("quiz.option.\(index)")
    }

    private func explanation(_ question: Question, feedback: QuizViewModel.AnswerFeedback) -> some View {
        CodeyCard(tint: feedback.correct ? CodeyColor.success : CodeyColor.danger) {
            VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                HStack(spacing: CodeySpacing.xs) {
                    Label(
                        feedback.correct ? "Correct" : "Not quite",
                        systemImage: feedback.correct ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .font(.codeyHeadline)
                    .foregroundStyle(feedback.correct ? CodeyColor.success : CodeyColor.danger)
                    Spacer(minLength: 0)
                    if let gain = feedback.gain {
                        Text("+\(gain.amount) XP")
                            .font(.codeyNumericSmall)
                            .foregroundStyle(CodeyColor.success)
                    }
                }
                if let breakdown = feedback.gain?.breakdown {
                    Text(breakdown)
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                }
                if feedback.retiredQuestion {
                    CodeyChip("Retired", systemImage: "checkmark.seal.fill", variant: .success)
                        .contentTransition(.symbolEffect(.replace))
                }
                CardMarkdownView(markdown: question.explanation)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func optionState(_ index: Int, question: Question) -> AnswerOptionState {
        guard let feedback = viewModel.feedback else { return .idle }
        if index == feedback.selectedIndex {
            return feedback.correct ? .selectedCorrect : .selectedWrong
        }
        if index == question.correctOptionIndex, !feedback.correct {
            return .revealedCorrect
        }
        return .idle
    }
}

