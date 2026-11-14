import SwiftUI

/// Coding exercises (FR-39), the Quiz tab's Exercises side: the bundled
/// exercises grouped by topic, one note per topic. No progress is kept
/// (S31), so the list is the same on every visit.
struct ExerciseList: View {
    let topics: [Topic]

    @State private var exercises: [Exercise] = []
    @State private var loadError: String?

    var body: some View {
        Group {
            if let loadError {
                EmptyStateView(systemImage: "exclamationmark.triangle", title: "Exercises didn't load", message: loadError)
                    .padding(.top, CodeySpacing.xl)
            } else {
                VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                    ForEach(sections, id: \.title) { section in
                        NoteSection(section.title) {
                            ForEach(section.exercises) { exercise in
                                NavigationLink {
                                    ExerciseView(exercise: exercise)
                                } label: {
                                    ChevronRow(
                                        systemImage: "chevron.left.forwardslash.chevron.right",
                                        title: exercise.title,
                                        subtitle: "\(exercise.language.displayName), \(exercise.blanks.count.counted("blank"))"
                                    )
                                    .accessibilityElement(children: .combine)
                                    .accessibilityHint("Opens the exercise")
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("exercise.\(exercise.id)")
                            }
                        }
                    }
                }
            }
        }
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
        return Dictionary(grouping: exercises, by: \.topicId)
            .map { (title: titles[$0.key] ?? $0.key, exercises: $0.value) }
            .sorted { $0.title < $1.title }
    }
}
