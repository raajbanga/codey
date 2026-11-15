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

    /// XP gold (S41): reward pills and the level bar. `xp` is the ink,
    /// `xpSoft` the fill behind it.
    static let xp = Color(.XP)
    static let xpSoft = Color(.xpSoft)

    /// One hue per topic on the Play board (S41, muted two-tone): `ink`
    /// for text and icons on the light `soft` tile, `fill` (mid tone) for
    /// the Play button and progress bars, labeled white. Topics outside the
    /// bundled bank fall back to brand.
    struct TopicHue: Equatable {
        let ink: Color
        let soft: Color
        let fill: Color

        static let teal = TopicHue(ink: Color(.topicTeal), soft: Color(.topicTealSoft), fill: Color(.topicTealFill))
        static let sand = TopicHue(ink: Color(.topicSand), soft: Color(.topicSandSoft), fill: Color(.topicSandFill))
        /// The app's own hue: the level card and header buttons.
        static let slate = TopicHue(ink: Color(.topicSlate), soft: Color(.topicSlateSoft), fill: Color(.topicSlateFill))
        static let coral = TopicHue(ink: Color(.topicCoral), soft: Color(.topicCoralSoft), fill: Color(.topicCoralFill))
        static let sky = TopicHue(ink: Color(.topicSky), soft: Color(.topicSkySoft), fill: Color(.topicSkyFill))
        static let rose = TopicHue(ink: Color(.topicRose), soft: Color(.topicRoseSoft), fill: Color(.topicRoseFill))
        static let olive = TopicHue(ink: Color(.topicOlive), soft: Color(.topicOliveSoft), fill: Color(.topicOliveFill))
        static let brand = TopicHue(ink: CodeyColor.brand, soft: CodeyColor.brandSoft, fill: CodeyColor.brand)

        static func of(topicID: String?) -> TopicHue {
            switch topicID {
            case "topic-algorithms": .teal
            case "topic-data-structures": .sky
            case "topic-python": .olive
            case "topic-databases": .sand
            case "topic-networking": .sky
            case "topic-os-basics": .rose
            case "topic-oop", "topic-swift": .coral
            default: .brand
            }
        }
    }

    /// Code-block background, shared by Textual (display) and Runestone
    /// (editor). Syntax colors are SyntaxRole.color.
    static let codeBackground = Color(.codeBackground)
}

extension EnvironmentValues {
    /// The learner's avatar color as the app's own accent (S42): tab tint,
    /// level card, header buttons, primary and secondary buttons. Nil is
    /// the default slate and brand ink. Topic tiles keep their topic hues.
    @Entry var appHue: CodeyColor.TopicHue?
}
