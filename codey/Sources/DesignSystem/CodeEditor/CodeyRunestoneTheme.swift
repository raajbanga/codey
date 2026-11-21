import Runestone
import UIKit

/// Runestone theme backed by the same syntax.* colors and SF Mono as
/// CardMarkdownView, so code looks identical in the builder and in study.
final class CodeyRunestoneTheme: Runestone.Theme {
    let font: UIFont
    let lineNumberFont: UIFont

    /// `.callout` in the deck builder; `.body` where code is the page's
    /// main task (a coding challenge).
    init(traits: UITraitCollection = .current, textStyle: UIFont.TextStyle = .callout) {
        let size = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traits).pointSize
        font = .monospacedSystemFont(ofSize: size, weight: .regular)
        lineNumberFont = .monospacedDigitSystemFont(ofSize: size * 0.8, weight: .regular)
    }

    let textColor = color(.plain)
    let gutterBackgroundColor = UIColor(resource: .codeBackground)
    let gutterHairlineColor = UIColor.separator
    let lineNumberColor = UIColor.secondaryLabel
    let selectedLineBackgroundColor = UIColor(resource: .brandSoft)
    let selectedLinesLineNumberColor = UIColor.label
    let selectedLinesGutterBackgroundColor = UIColor.clear
    let invisibleCharactersColor = UIColor.tertiaryLabel
    let pageGuideHairlineColor = UIColor.separator
    let pageGuideBackgroundColor = UIColor.clear
    let markedTextBackgroundColor = UIColor(resource: .brandSoft)

    func textColor(for highlightName: String) -> UIColor? {
        SyntaxRole(treeSitterCapture: highlightName).map(Self.color)
    }

    func fontTraits(for highlightName: String) -> FontTraits {
        SyntaxRole(treeSitterCapture: highlightName) == .keyword ? .bold : []
    }

    private static func color(_ role: SyntaxRole) -> UIColor {
        UIColor(resource: role.resource)
    }
}
