import SwiftData
import SwiftUI

struct TopicListView: View {
    @Query(sort: \Topic.title) private var topics: [Topic]

    var body: some View {
        ScrollView {
            if topics.isEmpty {
                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("No topics yet")
                            .font(.codeyHeadline)
                        Text("Pull to refresh or use Settings → Reset Local Data to reload the question bank.")
                            .font(.codeySubheadline)
                            .foregroundStyle(ThemeColor.muted)
                    }
                }
                .padding(CodeySpacing.md)
            } else {
                LazyVStack(spacing: CodeySpacing.md) {
                    ForEach(topics) { topic in
                        TopicCard(topic: topic)
                    }
                }
                .padding(CodeySpacing.md)
            }
        }
        .background(ThemeColor.canvas)
        .navigationTitle("Topics")
    }
}

private struct TopicCard: View {
    let topic: Topic

    var body: some View {
        CodeyCard {
            VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                HStack(spacing: CodeySpacing.md) {
                    Image(systemName: topic.iconName)
                        .font(.title2)
                        .foregroundStyle(ThemeColor.primary)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                        Text(topic.title)
                            .font(.codeyHeadline)
                        Text(topic.summary)
                            .font(.codeySubheadline)
                            .foregroundStyle(ThemeColor.muted)
                        CodeyBadge("\(topic.questions.count) questions", variant: .neutral)
                    }
                }

                HStack(spacing: CodeySpacing.sm) {
                    StudyModeLink("Practice", variant: .outline) {
                        PracticeSwipeView(topic: topic)
                    }
                    StudyModeLink("Quiz", variant: .primary) {
                        QuizModeView(topic: topic)
                    }
                }
            }
        }
    }
}

private struct StudyModeLink<Destination: View>: View {
    let title: String
    let variant: CodeyButtonVariant
    @ViewBuilder let destination: () -> Destination

    init(_ title: String, variant: CodeyButtonVariant, @ViewBuilder destination: @escaping () -> Destination) {
        self.title = title
        self.variant = variant
        self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, CodeySpacing.sm + 2)
                .foregroundStyle(variant == .primary ? .white : ThemeColor.primary)
                .background(variant == .primary ? ThemeColor.primary : .clear)
                .overlay {
                    if variant == .outline {
                        Capsule().stroke(ThemeColor.border, lineWidth: 1)
                    }
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        TopicListView()
    }
    .modelContainer(ModelContainerFactory.makePreview())
}
