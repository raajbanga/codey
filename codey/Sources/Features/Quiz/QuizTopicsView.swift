import SwiftData
import SwiftUI

/// Quiz tab root (replaces TopicListView): one card per topic with its tier
/// locks, accuracy over the last 50 answers (FR-36), and retired count.
/// Tap → QuizSetupView sheet → quiz as a full-screen cover.
struct QuizTopicsView: View {
    @Query(sort: \Topic.title) private var topics: [Topic]
    @Query private var progressRows: [QuestionProgress]
    @Query private var topicProgress: [TopicProgress]
    @Query private var records: [QuizAnswerRecord]
    @Query private var profiles: [UserProfile]

    @State private var setupTopic: Topic?
    @State private var pendingQuiz: QuizRequest?
    @State private var quiz: QuizRequest?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            if topics.isEmpty {
                EmptyStateView(
                    systemImage: "questionmark.bubble",
                    title: "No topics yet",
                    message: "The question bank loads on launch. Try restarting the app."
                )
                .padding(.top, CodeySpacing.xl)
            } else {
                LazyVStack(spacing: CodeySpacing.md) {
                    ForEach(topics) { topic in
                        Button {
                            setupTopic = topic
                        } label: {
                            QuizTopicRow(stats: stats(for: topic))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("quizTopic.\(topic.title)")
                    }
                }
                .padding(CodeySpacing.md)
            }
        }
        .background(CodeyColor.surface)
        .navigationTitle("Quiz")
        .sheet(item: $setupTopic, onDismiss: {
            // Present the quiz only after the sheet is gone.
            if let pendingQuiz {
                quiz = pendingQuiz
                self.pendingQuiz = nil
            }
        }) { topic in
            QuizSetupView(topic: topic) { mode in
                pendingQuiz = QuizRequest(topic: topic, mode: mode)
                setupTopic = nil
            }
        }
        .fullScreenCover(item: $quiz) { request in
            QuizModeView(request: request, context: modelContext)
        }
    }

    private func stats(for topic: Topic) -> QuizTopicStats {
        let progress = Dictionary(
            progressRows.filter { $0.topicId == topic.id }.map { ($0.questionId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let sticky = topicProgress.first { $0.topicId == topic.id }?.unlockedTiers ?? []
        return QuizTopicStats(
            topic: topic,
            tiers: QuizProgressStore.availability(
                questions: topic.questions,
                progress: progress,
                sticky: sticky,
                xp: profiles.first?.totalXP ?? 0
            ),
            accuracy: QuizProgressStore.accuracy(
                of: records.filter { $0.topicId == topic.id },
                window: GatingConfig.standard.accuracyWindow
            ),
            retired: topic.questions.filter { progress[$0.id]?.isRetired == true }.count,
            total: topic.questions.count
        )
    }
}

struct QuizTopicStats {
    let topic: Topic
    let tiers: [TierAvailability]
    let accuracy: Double?
    let retired: Int
    let total: Int
}

private struct QuizTopicRow: View {
    let stats: QuizTopicStats

    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 44

    var body: some View {
        CodeyCard {
            VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                HStack(alignment: .top, spacing: CodeySpacing.md) {
                    Image(systemName: stats.topic.iconName)
                        .font(.codeyTitle)
                        .foregroundStyle(CodeyColor.brand)
                        .frame(width: iconSize, height: iconSize)
                        .background(CodeyColor.brandSoft, in: .codey(CodeyRadius.sm))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                        Text(stats.topic.title)
                            .font(.codeyHeadline)
                            .foregroundStyle(CodeyColor.textPrimary)
                        Text(accuracyText)
                            .font(.codeySubheadline)
                            .foregroundStyle(CodeyColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.codeyCallout.weight(.semibold))
                        .foregroundStyle(CodeyColor.textSecondary)
                        .accessibilityHidden(true)
                }
                TierChipRow(tiers: stats.tiers)
                ProgressBar(
                    value: stats.total == 0 ? 0 : Double(stats.retired) / Double(stats.total),
                    label: "\(stats.retired) of \(stats.total) retired"
                )
            }
        }
        .contentShape(.rect(cornerRadius: CodeyRadius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens quiz setup")
    }

    private var accuracyText: String {
        guard let accuracy = stats.accuracy else { return "No answers yet" }
        return "\(Int((accuracy * 100).rounded()))% accuracy"
    }
}

#Preview {
    NavigationStack {
        QuizTopicsView()
    }
    .modelContainer(ModelContainerFactory.makePreview())
}
