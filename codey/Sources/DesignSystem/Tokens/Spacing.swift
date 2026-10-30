import CoreGraphics

/// Spacing scale (points). All padding and stack spacing use these tokens;
/// scripts/check-design-tokens.sh flags raw numbers.
enum CodeySpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
