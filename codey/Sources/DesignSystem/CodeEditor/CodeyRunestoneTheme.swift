import Runestone
import UIKit

/// Runestone theme backed by the same syntax.* colors and SF Mono as
/// CardMarkdownView, so code looks identical in the builder and in study.
final class CodeyRunestoneTheme: Runestone.Theme {
    let font: UIFont
    let lineNumberFont: UIFont

    init(traits: UITraitCollection = .current) {
        let size = UIFont.preferredFont(forTextStyle: .callout, compatibleWith: traits).pointSize
        font = .monospacedSystemFont(ofSize: size, weight: .regular)
        lineNumberFont = .monospacedDigitSystemFont(ofSize: size * 0.8, weight: .regular)
    }

    let textColor = color(.plain)
    let gutterBackgroundColor = UIColor(named: "CodeBackground") ?? .secondarySystemBackground
    let gutterHairlineColor = UIColor.separator
    let lineNumberColor = UIColor.secondaryLabel
    let selectedLineBackgroundColor = UIColor(named: "BrandSoft") ?? .systemFill
    let selectedLinesLineNumberColor = UIColor.label
    let selectedLinesGutterBackgroundColor = UIColor.clear
    let invisibleCharactersColor = UIColor.tertiaryLabel
    let pageGuideHairlineColor = UIColor.separator
    let pageGuideBackgroundColor = UIColor.clear
    let markedTextBackgroundColor = UIColor(named: "BrandSoft") ?? .systemFill

    func textColor(for highlightName: String) -> UIColor? {
        SyntaxRole(treeSitterCapture: highlightName).map(Self.color)
    }

    func fontTraits(for highlightName: String) -> FontTraits {
        SyntaxRole(treeSitterCapture: highlightName) == .keyword ? .bold : []
    }

    private static func color(_ role: SyntaxRole) -> UIColor {
        UIColor(named: role.assetName) ?? .label
    }
}
