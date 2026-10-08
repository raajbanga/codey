import SwiftUI

/// How each self-rating looks and feels (D14).
extension CardRating {
    var title: String {
        switch self {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    /// Mastery-delta hint under the title: ↺0 / = / +1 / +2.
    var deltaHint: String {
        switch self {
        case .again: "↺0"
        case .hard: "="
        case .good: "+1"
        case .easy: "+2"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .again: "Resets mastery to 0 and shows this card again later"
        case .hard: "Keeps mastery the same"
        case .good: "Adds 1 to mastery"
        case .easy: "Adds 2 to mastery"
        }
    }

    var tint: Color {
        switch self {
        case .again: CodeyColor.danger
        case .hard: CodeyColor.warning
        case .good: CodeyColor.brand
        case .easy: CodeyColor.success
        }
    }

    /// A distinct haptic per rating.
    var feedback: SensoryFeedback {
        switch self {
        case .again: .error
        case .hard: .impact(weight: .medium)
        case .good: .success
        case .easy: .levelChange
        }
    }

    /// Hardware-keyboard shortcut: 1–4.
    var keyEquivalent: KeyEquivalent {
        switch self {
        case .again: "1"
        case .hard: "2"
        case .good: "3"
        case .easy: "4"
        }
    }

    /// Swipe direction for this rating on a revealed card (D14, swipe-only).
    var swipeSymbol: String {
        switch self {
        case .again: "arrow.left"
        case .hard: "arrow.down"
        case .good: "arrow.right"
        case .easy: "arrow.up"
        }
    }

    /// Order of the gesture hint under the card: ← Again ↓ Hard ↑ Easy → Good.
    static let swipeHintOrder: [CardRating] = [.again, .hard, .easy, .good]

    /// The rating a drag maps to once past `threshold`: ← Again, → Good,
    /// ↑ Easy, ↓ Hard. The dominant axis wins.
    static func forSwipe(_ translation: CGSize, threshold: CGFloat) -> CardRating? {
        if abs(translation.height) > abs(translation.width) {
            if translation.height < -threshold { return .easy }
            if translation.height > threshold { return .hard }
            return nil
        }
        if translation.width > threshold { return .good }
        if translation.width < -threshold { return .again }
        return nil
    }
}
