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
                        Text("Sprint 2 will let you browse categorized CS tracks with mastery tracking.")
                            .font(.codeySubheadline)
                            .foregroundStyle(ThemeColor.muted)
                    }
                }
                .padding(CodeySpacing.md)
            } else {
                VStack(spacing: CodeySpacing.md) {
                    ForEach(topics, id: \.id) { topic in
                        CodeyCard {
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
                                    HStack {
                                        CodeyBadge("\(topic.questions.count) questions", variant: .neutral)
                                        CodeyBadge("CS Track", variant: .success)
                                    }
                                }
                            }
                        }
                    }

                    CodeyCard {
                        Text("Sprint 2 will add topic detail screens, question previews, and mastery progress per track.")
                            .font(.codeySubheadline)
                            .foregroundStyle(ThemeColor.muted)
                    }
                }
                .padding(CodeySpacing.md)
            }
        }
        .background(ThemeColor.canvas)
        .navigationTitle("Topics")
    }
}

#Preview {
    NavigationStack {
        TopicListView()
    }
    .modelContainer(PreviewContainer.make())
}
