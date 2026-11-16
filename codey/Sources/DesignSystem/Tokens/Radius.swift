import SwiftUI

/// Corner radius tokens and rules (D19).
///
/// - Controls use `.pill` (16), tags use `.tag` (12); capsules only for
///   progress bars and the onboarding dots.
/// - Anything that can wrap uses RoundedRectangle(md, .continuous).
/// - Nested surfaces are concentric: inner radius = outer radius − padding
///   (use ConcentricRectangle / .containerShape).
/// - Cards use lg; full-screen sheets keep the system corners.
enum CodeyRadius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
}

extension Shape where Self == RoundedRectangle {
    /// Continuous rounded rectangle with a radius token: `.clipShape(.codey(CodeyRadius.md))`.
    static func codey(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

extension Shape where Self == RoundedRectangle {
    /// Every tappable control (§3b, Nov 15): buttons, choice pills, tile
    /// actions, the search field. A touch rounder than md.
    static var pill: RoundedRectangle { .codey(16) }

    /// Tags (CodeyChip, XP and streak badges). A smaller radius than
    /// `.pill`, but tags are about 30 pt tall against 44–56 pt buttons, so
    /// it is a bigger share of the height and they read the roundest.
    static var tag: RoundedRectangle { .codey(12) }
}
