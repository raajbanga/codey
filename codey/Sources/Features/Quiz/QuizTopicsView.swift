import SwiftData
import SwiftUI

/// Quiz tab root. S40: one screen for both kinds of practice: a
/// Quizzes | Exercises switch (the exercise list used to be its own
/// pushed screen). Quizzes are bento tiles: tier locks, accuracy over the
/// last 50 answers (FR-36), and retired count. Tap → the quiz-setup
/// FloatingPanel → the quiz as a full-screen cover (both owned by the Router).
struct QuizTopicsView: View {
    enum Kind: String, CaseIterable {
        case quizzes = "Quizzes"
        case exercises = "Exercises"
    }

    @Query(sort: \Topic.title) private var topics: [Topic]
    @Query private var progressRows: [QuestionProgress]
    @Query private var topicProgress: [TopicProgress]
    @Query private var records: [QuizAnswerRecord]
    @Query private var profiles: [UserProfile]

    @Environment(Router.self) private var router
    @SceneStorage("quiz.kind") private var kind: Kind = .quizzes

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                PageHeader(title: "Quiz")
                Picker("Practice", selection: $kind) {
                    ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("quiz.kind")

                switch kind {
                case .quizzes: quizzes
                case .exercises: ExerciseList(topics: topics)
                }
            }
            .padding(CodeySpacing.md)
        }
        .codeyPaperBackground()
        .toolbarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var quizzes: some View {
        if topics.isEmpty {
            EmptyStateView(
                systemImage: "questionmark.bubble",
                title: "No topics yet",
                message: "The question bank loads on launch. Try restarting the app."
            )
            .padding(.top, CodeySpacing.xl)
        } else {
            BentoSection("Pick a topic") {
                ForEach(topics) { topic in
                    Button {
                        router.quizSetupTopic = topic
                    } label: {
                        QuizTopicTile(stats: stats(for: topic))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("quizTopic.\(topic.title)")
                }
            }
        }
    }

    private func stats(for topic: Topic) -> QuizTopicStats {
        let progress = progressRows.filter { $0.topicId == topic.id }.keyed(by: \.questionId)
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

private struct QuizTopicTile: View {
    let stats: QuizTopicStats

    var body: some View {
        BentoTile(icon: stats.topic.iconName, title: stats.topic.title, detail: detail) {
            TierChipRow(tiers: stats.tiers, compact: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens quiz setup")
    }

    private var detail: String {
        let accuracy = stats.accuracy.map { "\($0.percentText) accuracy" } ?? "No answers yet"
        return "\(accuracy)\n\(stats.retired) of \(stats.total) retired"
    }
}

#Preview {
    NavigationStack {
        QuizTopicsView()
    }
    .environment(Router())
    .modelContainer(ModelContainerFactory.makePreview())
}
