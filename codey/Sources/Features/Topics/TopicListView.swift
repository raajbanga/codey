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
                            .foregroundStyle(CodeyColor.textSecondary)
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
        .background(CodeyColor.surface)
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
                        .font(.codeyTitle)
                        .foregroundStyle(CodeyColor.brand)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                        Text(topic.title)
                            .font(.codeyHeadline)
                        Text(topic.summary)
                            .font(.codeySubheadline)
                            .foregroundStyle(CodeyColor.textSecondary)
                        CodeyChip("\(topic.questions.count) questions", variant: .neutral)
                    }
                }

                HStack(spacing: CodeySpacing.sm) {
                    NavigationLink {
                        PracticeSwipeView(topic: topic)
                    } label: {
                        Text("Practice").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(CodeyColor.brand)

                    NavigationLink {
                        QuizModeView(topic: topic)
                    } label: {
                        Text("Quiz").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CodeyColor.brandFill)
                }
                .fontWeight(.semibold)
                .lineLimit(1)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TopicListView()
    }
    .modelContainer(ModelContainerFactory.makePreview())
}
