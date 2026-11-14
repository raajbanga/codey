import SwiftData
import SwiftUI

/// Coding exercises (FR-39), reached from the top of the Quiz tab: the
/// bundled exercises grouped by topic. No progress is kept (S31), so the
/// list is the same on every visit.
struct ExerciseListView: View {
    @Query(sort: \Topic.title) private var topics: [Topic]

    @State private var exercises: [Exercise] = []
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            if let loadError {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "Exercises didn't load",
                    message: loadError
                )
                .padding(.top, CodeySpacing.xl)
            } else {
                VStack(alignment: .leading, spacing: CodeySpacing.md) {
                    ForEach(sections, id: \.title) { section in
                        Text(section.title)
                            .font(.codeyHeadline)
                            .foregroundStyle(CodeyColor.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.top, CodeySpacing.sm)
                        ForEach(section.exercises) { exercise in
                            NavigationLink {
                                ExerciseView(exercise: exercise)
                            } label: {
                                ExerciseRow(exercise: exercise)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("exercise.\(exercise.id)")
                        }
                    }
                }
                .padding(CodeySpacing.md)
            }
        }
        .codeyPaperBackground()
        .navigationTitle("Coding Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard exercises.isEmpty, loadError == nil else { return }
            do {
                exercises = try ExerciseLoader.load()
            } catch {
                loadError = String(describing: error)
            }
        }
    }

    /// Exercises by topic, in the Quiz tab's topic order.
    private var sections: [(title: String, exercises: [Exercise])] {
        let titles = Dictionary(topics.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        let grouped = Dictionary(grouping: exercises, by: \.topicId)
        return grouped
            .map { (title: titles[$0.key] ?? $0.key, exercises: $0.value) }
            .sorted { $0.title < $1.title }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        CodeyCard {
            HStack(spacing: CodeySpacing.md) {
                VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                    Text(exercise.title)
                        .font(.codeyHeadline)
                        .foregroundStyle(CodeyColor.textPrimary)
                    Text(exercise.prompt)
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                        .lineLimit(2)
                    HStack(spacing: CodeySpacing.xs) {
                        CodeyChip(exercise.language.displayName, systemImage: "chevron.left.forwardslash.chevron.right", variant: .brand)
                        CodeyChip(exercise.blanks.count == 1 ? "1 blank" : "\(exercise.blanks.count) blanks")
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.codeyCallout.weight(.semibold))
                    .foregroundStyle(CodeyColor.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect(cornerRadius: CodeyRadius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the exercise")
    }
}

/// Entry card at the top of the Quiz tab.
struct ExerciseEntryCard: View {
    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 44

    var body: some View {
        NavigationLink {
            ExerciseListView()
        } label: {
            CodeyCard {
                HStack(spacing: CodeySpacing.md) {
                    IconTile(systemName: "curlybraces", size: iconSize, radius: CodeyRadius.sm)
                    VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                        Text("Coding Exercises")
                            .font(.codeyHeadline)
                            .foregroundStyle(CodeyColor.textPrimary)
                        Text("Fill in the missing code and check it")
                            .font(.codeySubheadline)
                            .foregroundStyle(CodeyColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.codeyCallout.weight(.semibold))
                        .foregroundStyle(CodeyColor.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect(cornerRadius: CodeyRadius.lg))
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the coding exercises")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quiz.exercises")
    }
}

#Preview {
    NavigationStack {
        ExerciseListView()
    }
    .modelContainer(ModelContainerFactory.makePreview())
}
