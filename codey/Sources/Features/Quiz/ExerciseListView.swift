import SwiftUI

/// Coding exercises (FR-39) on Play (S41): one SolvableTile each, with what
/// a first solve pays (+10 XP a blank) or Solved once done. Goes inside a
/// BentoSection.
struct ExerciseTiles: View {
    let topics: [Topic]
    let solved: Set<String>
    /// Only this topic's exercises (a Library topic page); nil shows all.
    var topicID: String?

    /// Read from the catalog in body (not in `.task`): before a load the
    /// view has no content (an empty ForEach), so it never appears and the
    /// task never ran, which left the section empty.
    private var loaded: Result<[Exercise], Error> { ExerciseCatalog.shared.result }

    private var exercises: [Exercise] { (try? loaded.get()) ?? [] }
    private var loadError: String? {
        if case .failure(let error) = loaded { return String(describing: error) }
        return nil
    }

    var body: some View {
        Group {
            if let loadError {
                GameTile(icon: "exclamationmark.triangle", title: "Drills didn't load", detail: loadError, hue: .rose, filled: false)
            } else {
                ForEach(ordered) { exercise in
                    SolvableTile(
                        icon: "chevron.left.forwardslash.chevron.right",
                        title: exercise.title,
                        detail: exercise.language.displayName,
                        topicID: exercise.topicId,
                        isSolved: solved.contains(exercise.id),
                        xpReward: exercise.xpReward,
                        accessibilityHint: "Opens the drill",
                        identifier: "exercise.\(exercise.id)"
                    ) {
                        ExerciseView(exercise: exercise)
                    }
                }
            }
        }
    }

    private func topicTitle(_ exercise: Exercise) -> String {
        topics.first { $0.id == exercise.topicId }?.title ?? exercise.topicId
    }

    /// Unsolved first, then by topic and title.
    private var ordered: [Exercise] {
        exercises.filter { topicID == nil || $0.topicId == topicID }.sorted {
            let a = solved.contains($0.id), b = solved.contains($1.id)
            if a != b { return !a }
            return (topicTitle($0), $0.title) < (topicTitle($1), $1.title)
        }
    }
}
