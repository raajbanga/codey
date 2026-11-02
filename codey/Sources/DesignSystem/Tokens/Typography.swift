import SwiftUI

/// Type tokens. All are Dynamic Type text styles. Headings and numbers are
/// SF Rounded (the "notes on paper" softness); reading text stays SF Pro.
/// Numbers use monospaced digits so counters don't jitter.
///
/// The smallest token is footnote (13pt at the default size): nothing in
/// the app uses caption/caption2, which read too small on a phone.
extension Font {
    static let codeyDisplay = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let codeyTitle = Font.system(.title2, design: .rounded, weight: .semibold)
    static let codeyHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let codeyBody = Font.body
    /// Flashcard and quiz prompts/answers: a card is read at a glance, so
    /// it reads larger than body (title3, 20pt by default).
    static let codeyCardText = Font.title3
    static let codeyCallout = Font.callout
    static let codeySubheadline = Font.subheadline
    /// Labels, chips, metadata. Footnote, not caption.
    static let codeyCaption = Font.footnote
    /// XP, levels, counters. Pair with .contentTransition(.numericText()).
    static let codeyNumeric = Font.system(.title, design: .rounded, weight: .semibold).monospacedDigit()
    static let codeyNumericSmall = Font.system(.headline, design: .rounded, weight: .medium).monospacedDigit()
}

/// System navigation titles in SF Rounded, to match codeyDisplay /
/// codeyHeadline. SwiftUI has no modifier for this, so it goes through the
/// UIKit appearance proxy once at launch.
@MainActor
enum CodeyNavigationTitles {
    static func apply() {
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: rounded(.largeTitle, bold: true)]
        bar.titleTextAttributes = [.font: rounded(.headline, bold: true)]
    }

    private static func rounded(_ style: UIFont.TextStyle, bold: Bool) -> UIFont {
        var descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
        if let roundedDescriptor = descriptor.withDesign(.rounded) { descriptor = roundedDescriptor }
        if bold, let boldDescriptor = descriptor.withSymbolicTraits(.traitBold) { descriptor = boldDescriptor }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
