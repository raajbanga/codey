import SwiftUI

enum AnswerOptionState: Equatable {
    case idle
    case selectedCorrect
    case selectedWrong
    /// The right answer, shown after the user picked a wrong one.
    case revealedCorrect
}

/// Multiple-choice answer row (replaces QuizOptionRow, fixes B14): md radius
/// so long answers wrap cleanly, A/B/C/D badge, and state shown by icon +
/// color + VoiceOver value, never color alone.
struct AnswerOptionRow: View {
    let index: Int
    let title: String
    let state: AnswerOptionState
    let isLocked: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 28

    private var letter: String {
        String(UnicodeScalar(UInt8(65 + min(max(index, 0), 25))))
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: CodeySpacing.md) {
                Text(letter)
                    .font(.codeySubheadline.weight(.semibold))
                    .foregroundStyle(badgeForeground)
                    .frame(width: badgeSize, height: badgeSize)
                    .background(badgeBackground, in: Circle())

                Text(title)
                    .font(.codeyBody)
                    .foregroundStyle(CodeyColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let icon {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(tint)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, CodeySpacing.sm + CodeySpacing.xs)
            .padding(.horizontal, CodeySpacing.md)
            .background(fill, in: .codey(CodeyRadius.md))
            .overlay {
                RoundedRectangle.codey(CodeyRadius.md)
                    .strokeBorder(stroke, style: StrokeStyle(lineWidth: state == .idle ? 1 : 1.5, dash: state == .revealedCorrect ? [6, 4] : []))
            }
            .contentShape(.rect(cornerRadius: CodeyRadius.md))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked && state == .idle ? 0.55 : 1)
        .codeyAnimation(CodeyMotion.snappy, value: state)
        .sensoryFeedback(trigger: state) { _, new in
            switch new {
            case .selectedCorrect: .success
            case .selectedWrong: .error
            default: nil
            }
        }
        .accessibilityLabel("Option \(letter): \(title)")
        .accessibilityValue(accessibilityState)
    }

    private var tint: Color {
        switch state {
        case .idle: CodeyColor.brand
        case .selectedCorrect, .revealedCorrect: CodeyColor.success
        case .selectedWrong: CodeyColor.danger
        }
    }

    private var icon: String? {
        switch state {
        case .idle: nil
        case .selectedCorrect: "checkmark.circle.fill"
        case .selectedWrong: "xmark.circle.fill"
        case .revealedCorrect: "checkmark.circle"
        }
    }

    private var fill: Color {
        switch state {
        case .idle: CodeyColor.surfaceRaised
        case .selectedCorrect, .revealedCorrect: CodeyColor.Soft.success
        case .selectedWrong: CodeyColor.Soft.danger
        }
    }

    private var stroke: Color {
        state == .idle ? CodeyColor.separator : tint
    }

    // Every pairing here is one scripts/palette checks at 4.5:1.
    private var badgeForeground: Color { tint }

    private var badgeBackground: Color {
        state == .idle ? CodeyColor.brandSoft : CodeyColor.surfaceRaised
    }

    private var accessibilityState: String {
        switch state {
        case .idle: ""
        case .selectedCorrect: "Your answer. Correct."
        case .selectedWrong: "Your answer. Incorrect."
        case .revealedCorrect: "Correct answer."
        }
    }
}
