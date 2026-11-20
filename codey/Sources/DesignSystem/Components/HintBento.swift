import SwiftUI

/// Hints behind a tap (S45): one note per hint, closed until opened, and
/// each hint locked until the one before it is open, so a student reads
/// them in order. Used by drills and coding challenges.
///
///     ╭ * Hint 1                  ⌄ ╮     ╭ * Hint 1                  ⌃ ╮
///     ╰─────────────────────────────╯     │ The loop must still run…    │
///     ╭ x Hint 2    Open hint 1 first ╮   ╰─────────────────────────────╯
struct HintBento: View {
    let hints: [String]
    var hue: CodeyColor.TopicHue = .slate
    /// Prefix for UI-test ids: "<id>.hint.1".
    var idPrefix = "hints"
    @State private var opened = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            ForEach(hints.indices, id: \.self) { index in
                row(index)
            }
        }
        // New hints (another drill loaded in place) start closed.
        .onChange(of: hints) { opened = 0 }
    }

    private func row(_ index: Int) -> some View {
        let isOpen = index < opened
        let isLocked = index > opened
        return Button {
            guard !isLocked else { return }
            withCodeyAnimation(reduceMotion: reduceMotion) {
                opened = isOpen ? index : index + 1
            }
        } label: {
            VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                HStack(spacing: CodeySpacing.sm) {
                    // As a GameTile's icon on a plain note: the topic's fill.
                    Icon(isLocked ? "lock" : "lightbulb", size: 24, relativeTo: .title2)
                        .foregroundStyle(isLocked ? CodeyColor.textSecondary : hue.fill)
                    Text("Hint \(index + 1)")
                        .font(.codeyHeadline)
                        .foregroundStyle(isLocked ? CodeyColor.textSecondary : CodeyColor.textPrimary)
                    Spacer(minLength: 0)
                    if isLocked {
                        Text("Open hint \(index) first")
                            .font(.codeyCaption)
                            .foregroundStyle(CodeyColor.textSecondary)
                    } else {
                        Icon(isOpen ? "chevron.up" : "chevron.down", size: 18, relativeTo: .headline)
                            .foregroundStyle(CodeyColor.textSecondary)
                    }
                }
                if isOpen {
                    Text(ExerciseView.inline(hints[index]))
                        .font(.codeyBody)
                        .foregroundStyle(CodeyColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }
            }
            .codeyCard()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isOpen ? "Hint \(index + 1): \(hints[index])" : "Hint \(index + 1)")
        .accessibilityHint(isLocked ? "Open hint \(index) first" : isOpen ? "Hides the hint" : "Shows the hint")
        .accessibilityIdentifier("\(idPrefix).hint.\(index + 1)")
    }
}

#Preview {
    HintBento(hints: ["Think about the loop bounds.", "Blank 1 compares `low` and `high`."])
        .padding()
        .codeyPaperBackground()
}
