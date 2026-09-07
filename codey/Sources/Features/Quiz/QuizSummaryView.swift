import SwiftUI

struct QuizSummaryView: View {
    @Environment(\.dismiss) private var dismiss

    let session: QuizSession
    let topicTitle: String

    var body: some View {
        ScrollView {
            VStack(spacing: CodeySpacing.md) {
                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.md) {
                        Text("Quiz Complete!")
                            .font(.codeyHeadline)

                        Text(topicTitle)
                            .font(.codeySubheadline)
                            .foregroundStyle(ThemeColor.muted)

                        Divider()

                        summaryRow(
                            label: "Score",
                            value: "\(session.correctCount)/\(session.totalQuestions) correct"
                        )

                        summaryRow(
                            label: "XP Earned",
                            value: "+\(session.sessionXPEarned) XP"
                        )

                        summaryRow(
                            label: "Best Streak",
                            value: "\(session.bestAnswerStreak) in a row"
                        )
                    }
                }

                CodeyButton("Back to Topics", variant: .primary, size: .lg) {
                    dismiss()
                }
            }
            .padding(CodeySpacing.md)
        }
        .background(ThemeColor.canvas)
        .navigationTitle("Summary")
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.codeySubheadline)
                .foregroundStyle(ThemeColor.muted)
            Spacer()
            Text(value)
                .font(.codeyHeadline)
                .foregroundStyle(ThemeColor.primary)
        }
    }
}

#Preview {
    NavigationStack {
        QuizSummaryView(
            session: {
                let session = QuizSession(totalQuestions: 5)
                session.correctCount = 4
                session.sessionXPEarned = 55
                session.bestAnswerStreak = 3
                return session
            }(),
            topicTitle: "Data Structures"
        )
    }
}
