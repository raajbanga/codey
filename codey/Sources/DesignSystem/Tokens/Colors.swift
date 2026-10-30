import SwiftUI

/// Color tokens. Views use these, never raw Color(...) or hex.
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
    static let brand = Color("Brand")
    static let brandFill = Color("BrandFill")
    static let onBrandFill = Color("OnBrandFill")
    /// Pastel brand tint behind brand text (chips, icon tiles, inline code).
    static let brandSoft = Color("BrandSoft")

    // Surfaces
    static let surface = Color("Surface")
    static let surfaceRaised = Color("SurfaceRaised")
    static let separator = Color("Separator")
    /// Neutral fill for chips and idle controls.
    static let fillNeutral = Color("FillNeutral")
    /// The faint dot grid on the paper background. Decoration, never text.
    static let paperDot = Color("PaperDot")

    // Text
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")

    // Status
    static let success = Color("Success")
    static let warning = Color("Warning")
    static let danger = Color("Danger")

    enum Tier {
        static let easy = Color("TierEasy")
        static let medium = Color("TierMedium")
        static let hard = Color("TierHard")
    }

    /// Pastel fills behind a status/tier color's own text. Paired by name
    /// (Success → SuccessSoft) so palette.py can check each pair.
    enum Soft {
        static let success = Color("SuccessSoft")
        static let warning = Color("WarningSoft")
        static let danger = Color("DangerSoft")
        static let easy = Color("TierEasySoft")
        static let medium = Color("TierMediumSoft")
        static let hard = Color("TierHardSoft")
    }

    /// Code-block background, shared by Textual (display) and Runestone
    /// (editor). Syntax colors are SyntaxRole.color.
    static let codeBackground = Color("CodeBackground")
}
