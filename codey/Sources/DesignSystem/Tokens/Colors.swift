import SwiftUI

/// Color tokens. Views use these, never raw Color(...) or hex. Each wraps
/// Xcode's generated ColorResource, so a renamed asset fails the build.
///
/// Sprint 3 facelift (S9, "pastel ink"): every color lives in
/// Assets.xcassets/Colors with light, dark, and (for the neutrals) Increase
/// Contrast variants, generated from scripts/palette/palette.py, which checks
/// every text/background pair at ≥ 4.5:1 (table in codey/DESIGN_SYSTEM.md).
/// Neutrals are custom rather than iOS semantic colors so the paper tone
/// stays warm.
enum CodeyColor {
    // Brand. `brand` is ink for text, icons, and tint. `brandFill` is the
    // pastel button fill; its label is `onBrandFill`, never white.
    static let brand = Color(.brand)
    static let brandFill = Color(.brandFill)
    static let onBrandFill = Color(.onBrandFill)
    /// Pastel brand tint behind brand text (chips, icon tiles, inline code).
    static let brandSoft = Color(.brandSoft)

    // Surfaces
    static let surface = Color(.surface)
    static let surfaceRaised = Color(.surfaceRaised)
    static let separator = Color(.separator)
    /// Neutral fill for chips and idle controls.
    static let fillNeutral = Color(.fillNeutral)
    /// The faint dot grid on the paper background. Decoration, never text.
    static let paperDot = Color(.paperDot)

    // Text
    static let textPrimary = Color(.textPrimary)
    static let textSecondary = Color(.textSecondary)

    // Status
    static let success = Color(.success)
    static let warning = Color(.warning)
    static let danger = Color(.danger)

    enum Tier {
        static let easy = Color(.tierEasy)
        static let medium = Color(.tierMedium)
        static let hard = Color(.tierHard)
    }

    /// Pastel fills behind a status/tier color's own text. Paired by name
    /// (Success → SuccessSoft) so palette.py can check each pair.
    enum Soft {
        static let success = Color(.successSoft)
        static let warning = Color(.warningSoft)
        static let danger = Color(.dangerSoft)
        static let easy = Color(.tierEasySoft)
        static let medium = Color(.tierMediumSoft)
        static let hard = Color(.tierHardSoft)
    }

    /// Code-block background, shared by Textual (display) and Runestone
    /// (editor). Syntax colors are SyntaxRole.color.
    static let codeBackground = Color(.codeBackground)
}
