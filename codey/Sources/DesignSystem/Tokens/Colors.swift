import SwiftUI

/// Color tokens. Views use these, never raw Color(...) or hex.
///
/// Brand, status, tier, and syntax colors live in Assets.xcassets/Colors with
/// light and dark variants; every text/background pair is checked at ≥ 4.5:1
/// by scripts/palette/palette.py (table in codey/DESIGN_SYSTEM.md).
/// Surfaces, separators, and text use iOS semantic colors so they track
/// Increase Contrast and the grouped/inset hierarchy for free.
enum CodeyColor {
    // Brand (D13). `brand` is for text, icons, and tint. `brandFill` sits
    // behind white labels; in dark mode no single indigo passes both.
    static let brand = Color("Brand")
    static let brandFill = Color("BrandFill")
    /// ~12–16% brand tint for chips and inline-code fills.
    static let brandSoft = Color("BrandSoft")

    // Surfaces
    static let surface = Color(uiColor: .systemGroupedBackground)
    static let surfaceRaised = Color(uiColor: .secondarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)
    /// Neutral fill for chips and idle controls.
    static let fillNeutral = Color(uiColor: .tertiarySystemFill)

    // Text
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textOnFill = Color.white

    // Status
    static let success = Color("Success")
    static let warning = Color("Warning")
    static let danger = Color("Danger")

    enum Tier {
        static let easy = Color("TierEasy")
        static let medium = Color("TierMedium")
        static let hard = Color("TierHard")
    }

    /// Code-block background, shared by Textual (display) and Runestone
    /// (editor). Syntax colors are SyntaxRole.color.
    static let codeBackground = Color("CodeBackground")

    /// Tinted background for a status/tier color behind its own text: 12% in
    /// light, 16% in dark (the opacities scripts/palette checks at 4.5:1).
    static func softFill(_ color: Color, for scheme: ColorScheme) -> Color {
        color.opacity(scheme == .dark ? 0.16 : 0.12)
    }
}
