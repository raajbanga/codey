import SwiftData
import SwiftUI

/// Focus-mode quiz (D8). Presented as a .fullScreenCover.
///
///     ✕  ▮▮▮▯▯▯▯▯▯▯   🔥 3   1,240 XP
///     ╭ ◇ Medium · Review ─ prompt ╮
///     (A) (B) (C) (D)
///     ╭ explanation ╮      [ Next ]  ← glass, pinned
struct QuizModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: QuizViewModel
    @State private var toastLevel: Int?
    @State private var pulsing = false

    init(request: QuizRequest, context: ModelContext) {
        _viewModel = State(initialValue: QuizViewModel(topic: request.topic, mode: request.mode, context: context))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
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
                QuizSummaryView(viewModel: viewModel) { dismiss() }
            } else if let question = viewModel.currentQuestion {
                questionView(question)
            }
        }
        .background(CodeyColor.surface.ignoresSafeArea())
        .overlay(alignment: .top) { levelToast }
        .onChange(of: viewModel.hasAnswered) { _, answered in
            guard answered, !reduceMotion else { return }
            withAnimation(CodeyMotion.bouncy) { pulsing = true }
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(CodeyMotion.smooth) { pulsing = false }
            }
        }
        .onChange(of: viewModel.levelUpToast) { _, level in
            guard let level else { return }
            showToast(level)
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: CodeySpacing.sm) {
            CloseButton(label: "Close quiz") { dismiss() }
                .accessibilityIdentifier("quiz.close")

            if !viewModel.isFinished, !viewModel.questions.isEmpty {
                SegmentedQuizProgress(results: viewModel.results, current: viewModel.index)
                if viewModel.streak >= 2 {
                    CodeyChip("\(viewModel.streak)", systemImage: "flame.fill", variant: .warning)
                        .contentTransition(.numericText())
                        .accessibilityLabel("Streak \(viewModel.streak)")
                        .transition(CodeyMotion.popTransition(reduceMotion: reduceMotion))
                }
                if !viewModel.isPractice {
                    XPGainLabel(total: viewModel.profileXP, lastGain: viewModel.feedback?.gain)
                }
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, CodeySpacing.md)
        .padding(.vertical, CodeySpacing.xs)
        .codeyAnimation(CodeyMotion.snappy, value: viewModel.streak)
    }

    // MARK: Question

    private func questionView(_ question: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.md) {
                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        HStack(spacing: CodeySpacing.xs) {
                            CodeyChip(tier: question.difficulty)
                            if viewModel.reviewIDs.contains(question.id) {
                                CodeyChip("Review", systemImage: "arrow.counterclockwise", variant: .brand)
                            }
                            if viewModel.isPractice {
                                CodeyChip("Practice · no XP", variant: .neutral)
                            }
                            Spacer(minLength: 0)
                            Text("\(viewModel.index + 1) of \(viewModel.questions.count)")
                                .font(.codeyCaption)
                                .foregroundStyle(CodeyColor.textSecondary)
                        }
                        CardMarkdownView(markdown: question.prompt)
                    }
                }

                VStack(spacing: CodeySpacing.sm) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        AnswerOptionRow(
                            index: index,
                            title: option,
                            state: optionState(index, question: question),
                            isLocked: viewModel.hasAnswered
                        ) {
                            withCodeyAnimation(reduceMotion: reduceMotion) { viewModel.select(index) }
                        }
                        .scaleEffect(pulse(index, question: question) ? 1.03 : 1)
                        .accessibilityIdentifier("quiz.option.\(index)")
                    }
                }

                if let feedback = viewModel.feedback {
                    explanation(question, feedback: feedback)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(CodeySpacing.md)
        }
        .id(question.id)
        .safeAreaInset(edge: .bottom) {
            if viewModel.hasAnswered {
                CodeyButton(
                    viewModel.isLastQuestion ? "See Results" : "Next",
                    systemImage: viewModel.isLastQuestion ? "flag.checkered" : "arrow.right",
                    kind: .glassPrimary,
                    fullWidth: true
                ) {
                    withCodeyAnimation(reduceMotion: reduceMotion) { viewModel.next() }
                }
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityIdentifier("quiz.next")
                .padding(.horizontal, CodeySpacing.md)
                .padding(.bottom, CodeySpacing.sm)
                .transition(.opacity)
            }
        }
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
                        .font(.codeyCaption)
                        .foregroundStyle(CodeyColor.textSecondary)
                }
                if feedback.retiredQuestion {
                    CodeyChip("Retired", systemImage: "checkmark.seal.fill", variant: .success)
                        .symbolEffect(.bounce, value: feedback.retiredQuestion)
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

    /// The correct row pulses once after answering.
    private func pulse(_ index: Int, question: Question) -> Bool {
        !reduceMotion && viewModel.hasAnswered && index == question.correctOptionIndex && pulsing
    }

    // MARK: Level-up toast

    @ViewBuilder
    private var levelToast: some View {
        if let toastLevel {
            Label("Level \(toastLevel)!", systemImage: "arrow.up.circle.fill")
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.brand)
                .padding(.horizontal, CodeySpacing.lg)
                .padding(.vertical, CodeySpacing.sm)
                .glassEffect(.regular, in: .capsule)
                .symbolEffect(.bounce, value: toastLevel)
                .padding(.top, CodeySpacing.xxl)
                .transition(CodeyMotion.popTransition(reduceMotion: reduceMotion))
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func showToast(_ level: Int) {
        withCodeyAnimation(CodeyMotion.bouncy, reduceMotion: reduceMotion) { toastLevel = level }
        UIAccessibility.post(notification: .announcement, argument: "Level \(level)!")
        Task {
            try? await Task.sleep(for: .seconds(2))
            withCodeyAnimation(reduceMotion: reduceMotion) { toastLevel = nil }
            viewModel.levelUpToast = nil
        }
    }
}

/// One tick per question, colored correct / wrong as you go; the current
/// one is brand. Ticks are fixed-height bars (radius = half the height).
private struct SegmentedQuizProgress: View {
    let results: [Bool?]
    let current: Int

    var body: some View {
        HStack(spacing: CodeySpacing.xxs) {
            ForEach(results.indices, id: \.self) { index in
                RoundedRectangle.codey(CodeyRadius.xs / 2)
                    .fill(color(index))
                    .frame(height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Question \(min(current + 1, results.count)) of \(results.count)")
        .accessibilityValue("\(results.filter { $0 == true }.count) correct so far")
    }

    private func color(_ index: Int) -> Color {
        switch results[index] {
        case .some(true): CodeyColor.success
        case .some(false): CodeyColor.danger
        case nil: index == current ? CodeyColor.brand : CodeyColor.fillNeutral
        }
    }
}
