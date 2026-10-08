import SwiftData
import SwiftUI

struct QuizModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    let topic: Topic

    @State private var questions: [Question] = []
    @State private var currentIndex = 0
    @State private var session: QuizSession?
    @State private var selectedOptionIndex: Int?
    @State private var hasAnswered = false
    @State private var showSummary = false

    private var profile: UserProfile? { profiles.first }

    private var currentQuestion: Question? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var body: some View {
        Group {
            if showSummary, let session {
                QuizSummaryView(session: session, topicTitle: topic.title)
            } else if let question = currentQuestion, let session {
                quizContent(question: question, session: session)
            } else {
                ProgressView()
            }
        }
        .background(CodeyColor.surface)
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                xpHeader
            }
        }
        .onAppear {
            if questions.isEmpty {
                questions = topic.questions.shuffled()
                session = QuizSession(totalQuestions: questions.count)
            }
        }
    }

    private var xpHeader: some View {
        VStack(spacing: 2) {
            Text("\(profile?.totalXP ?? 0) XP")
                .font(.codeySubheadline.weight(.semibold))
            if let session, session.sessionXPEarned > 0 {
                Text("+\(session.sessionXPEarned) this session")
                    .font(.codeyCaption)
                    .foregroundStyle(CodeyColor.success)
            }
        }
    }

    @ViewBuilder
    private func quizContent(question: Question, session: QuizSession) -> some View {
        ScrollView {
            VStack(spacing: CodeySpacing.md) {
                HStack {
                    CodeyChip(
                        "Question \(currentIndex + 1)/\(questions.count)",
                        variant: .neutral
                    )
                    if session.answerStreak > 0 {
                        CodeyChip("\(session.answerStreak) streak", variant: .success)
                    }
                    Spacer()
                }

                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        CodeyChip(tier: question.difficulty)
                        CardMarkdownView(markdown: question.prompt)
                    }
                }

                VStack(spacing: CodeySpacing.sm) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        AnswerOptionRow(
                            index: index,
                            title: option,
                            state: optionState(for: index, question: question),
                            isLocked: hasAnswered
                        ) {
                            selectOption(index, question: question, session: session)
                        }
                    }
                }

                if hasAnswered {
                    CodeyCard {
                        Text(question.explanation)
                            .font(.codeySubheadline)
                            .foregroundStyle(CodeyColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    CodeyButton(
                        currentIndex + 1 < questions.count ? "Next" : "See Results",
                        fullWidth: true
                    ) {
                        advance()
                    }
                }
            }
            .padding(CodeySpacing.md)
        }
    }

    private func optionState(for index: Int, question: Question) -> AnswerOptionState {
        guard hasAnswered, let selected = selectedOptionIndex else { return .idle }

        if index == selected {
            return index == question.correctOptionIndex ? .selectedCorrect : .selectedWrong
        }

        if index == question.correctOptionIndex, selected != question.correctOptionIndex {
            return .revealedCorrect
        }

        return .idle
    }

    private func selectOption(_ index: Int, question: Question, session: QuizSession) {
        guard !hasAnswered, let profile else { return }

        selectedOptionIndex = index
        hasAnswered = true

        let isCorrect = index == question.correctOptionIndex
        session.recordAnswer(correct: isCorrect, profile: profile, context: modelContext)
    }

    private func advance() {
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            selectedOptionIndex = nil
            hasAnswered = false
        } else {
            showSummary = true
        }
    }
}
