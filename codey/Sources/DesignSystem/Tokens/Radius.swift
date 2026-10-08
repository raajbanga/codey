import SwiftUI

/// Corner radius tokens and rules (D19).
///
/// - Capsule ONLY for single-line, fixed-height controls (chips, badges,
///   single-line buttons, the tab pill).
/// - Anything that can wrap uses RoundedRectangle(md, .continuous).
/// - Nested surfaces are concentric: inner radius = outer radius − padding
///   (use `concentric(outer:inset:)` or ConcentricRectangle/.containerShape).
/// - Cards use lg; full-screen sheets keep the system corners.
enum CodeyRadius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28

    /// Radius for a surface inset by `inset` inside one with radius `outer`,
    /// so both curves share a center. Never below `xs` (tiny radii look
    /// like mistakes), unless the outer radius itself is smaller.
    static func concentric(outer: CGFloat, inset: CGFloat) -> CGFloat {
        min(outer, max(outer - inset, xs))
    }
}

extension Shape where Self == RoundedRectangle {
    /// Continuous rounded rectangle with a radius token: `.clipShape(.codey(CodeyRadius.md))`.
    static func codey(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
