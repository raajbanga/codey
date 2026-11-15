import SwiftUI

/// What an answer row shows: untouched, the user's pick (right or wrong), or
/// the right answer revealed after a wrong pick.
enum AnswerOptionState: Equatable {
    case idle
    case selectedCorrect
    case selectedWrong
    /// The right answer, shown after the user picked a wrong one.
    case revealedCorrect
}

/// Multiple-choice answer row (replaces QuizOptionRow, fixes B14): md radius
/// so long answers wrap cleanly, A/B/C/D badge. State is fill + edge (dashed
/// for the revealed answer) + VoiceOver value. No state icon (S41): it
/// changed a tile's height on answer, and the explanation below carries ✓/✕.
struct AnswerOptionRow: View {
    let index: Int
    let title: String
    let state: AnswerOptionState
    let isLocked: Bool
    /// A tile in the 2×2 answer grid (S41): text centered, no letter badge.
    var asTile = false
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 60

    /// The answer with inline Markdown (`code`, **bold**) rendered, as on
    /// the question card; plain text if it doesn't parse.
    private var titleText: Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard let attributed = try? AttributedString(markdown: title, options: options) else { return Text(title) }
        return Text(attributed)
    }

    private var letter: String {
        String(UnicodeScalar(UInt8(65 + min(max(index, 0), 25))))
    }

    var body: some View {
        Button {
            // VoiceOver can still activate a row that ignores touches.
            if !isLocked { action() }
        } label: {
            if asTile {
                tileLabel
            } else {
                rowLabel
            }
        }
        // Not .disabled: a disabled .plain button dims its whole label, which
        // greyed out the picked and revealed rows too (contrast below 4.5:1).
        // Only the untouched rows fade once the question is locked.
        .buttonStyle(AnswerRowButtonStyle())
        .allowsHitTesting(!isLocked)
        .accessibilityAddTraits(isLocked ? .isStaticText : [])
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

    private var tileLabel: some View {
        titleText
            .font(.codeyBody.weight(.medium))
            .foregroundStyle(CodeyColor.textPrimary)
            .multilineTextAlignment(.center)
        .padding(CodeySpacing.md)
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(fill, in: .codey(CodeyRadius.lg))
        .overlay {
            RoundedRectangle.codey(CodeyRadius.lg)
                .strokeBorder(state == .idle ? CodeyColor.separator : tint, style: StrokeStyle(lineWidth: state == .idle ? 1.5 : 2.5, dash: state == .revealedCorrect ? [6, 4] : []))
        }
        .contentShape(.rect(cornerRadius: CodeyRadius.lg))
    }

    private var rowLabel: some View {
            HStack(alignment: .center, spacing: CodeySpacing.md) {
                Text(letter)
                    .font(.codeySubheadline.weight(.semibold))
                    .foregroundStyle(badgeForeground)
                    .frame(width: badgeSize, height: badgeSize)
                    .background(badgeBackground, in: Circle())

                titleText
                    .font(.codeyBody)
                    .foregroundStyle(CodeyColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, CodeySpacing.md)
            .padding(.horizontal, CodeySpacing.md)
            .frame(minHeight: rowHeight)
            .background(fill, in: .codey(CodeyRadius.md))
            .overlay {
                RoundedRectangle.codey(CodeyRadius.md)
                    .strokeBorder(stroke, style: StrokeStyle(lineWidth: state == .idle ? 1 : 1.5, dash: state == .revealedCorrect ? [6, 4] : []))
            }
            .contentShape(.rect(cornerRadius: CodeyRadius.md))
    }

    private var tint: Color {
        switch state {
        case .idle: CodeyColor.brand
        case .selectedCorrect, .revealedCorrect: CodeyColor.success
        case .selectedWrong: CodeyColor.danger
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

/// Plain press feedback without the system's disabled dimming.
private struct AnswerRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}
