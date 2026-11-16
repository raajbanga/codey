import SwiftUI

/// A card's 0–5 mastery score as five dots (S19), so the score that
/// retires a card is visible instead of hidden. Filled dots use the brand
/// color; empty ones are outlined, so the count never relies on color alone.
/// An optional change label ("+2", "Reset", "No change") follows a rating.
struct MasteryDots: View {
    let score: Int
    var maxScore: Int = Flashcard.maxMastery
    /// The score before the rating that is being shown, if any.
    var previousScore: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let dotSize = CodeySpacing.sm

    var body: some View {
        let score = score
        HStack(spacing: CodeySpacing.sm) {
            HStack(spacing: CodeySpacing.xs) {
                // @Sendable, so the closure isn't main-actor isolated: during
                // the card flip SwiftUI builds the dots on its AsyncRenderer
                // thread, where Swift 6's isolation check traps (CI crash).
                ForEach(0..<maxScore, id: \.self) { @Sendable index in
                    Self.dot(filled: index < score)
                }
            }
            if let change {
                Text(change.text)
                    .font(.codeySubheadline.weight(.semibold))
                    .foregroundStyle(change.color)
                    .transition(.opacity)
            }
        }
        .codeyAnimation(CodeyMotion.smooth, value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mastery \(score) of \(maxScore)")
        .accessibilityValue(change?.text ?? "")
    }

    nonisolated private static func dot(filled: Bool) -> some View {
        Circle()
            .strokeBorder(filled ? CodeyColor.brand : CodeyColor.textSecondary, lineWidth: 1)
            .background(Circle().fill(filled ? CodeyColor.brand : .clear))
            .frame(width: Self.dotSize, height: Self.dotSize)
    }

    private var change: (text: String, color: Color)? {
        guard let previousScore else { return nil }
        if score > previousScore { return ("+\(score - previousScore)", CodeyColor.success) }
        if score < previousScore { return ("Reset", CodeyColor.danger) }
        return ("No change", CodeyColor.textSecondary)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: CodeySpacing.md) {
        MasteryDots(score: 0)
        MasteryDots(score: 2, previousScore: 0)
        MasteryDots(score: 0, previousScore: 3)
        MasteryDots(score: 5, previousScore: 5)
    }
    .padding()
}
