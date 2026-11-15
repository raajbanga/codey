import SwiftUI

/// Type tokens. All are Dynamic Type text styles. Headings and numbers are
/// SF Rounded (the "notes on paper" softness); reading text stays SF Pro.
/// Numbers use monospaced digits so counters don't jitter.
///
/// S41: two steps up the type ramp for legibility, so text fills the tiles
/// instead of leaving white space (at the default size: body and headings
/// 22pt, secondary 20pt, labels 17pt, card text 28pt, titles 34pt). Code
/// stays at body so lines don't wrap.
extension Font {
    static let codeyDisplay = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let codeyTitle = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    static let codeyHeadline = Font.system(.title2, design: .rounded, weight: .semibold)
    static let codeyBody = Font.title2
    /// Flashcard and quiz prompts/answers: a card is read at a glance, so
    /// it reads larger than body (title, 28pt by default).
    static let codeyCardText = Font.title
    static let codeyCallout = Font.title3
    static let codeySubheadline = Font.title3
    /// Labels, chips, metadata.
    static let codeyCaption = Font.body
    /// XP, levels, counters. Pair with .contentTransition(.numericText()).
    static let codeyNumeric = Font.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit()
    static let codeyNumericSmall = Font.system(.title2, design: .rounded, weight: .medium).monospacedDigit()
    /// Typed code (exercise answers): monospaced so spacing reads as typed.
    static let codeyCode = Font.system(.body, design: .monospaced)
}

/// System navigation titles in SF Rounded, to match codeyDisplay /
/// codeyHeadline. SwiftUI has no modifier for this, so it goes through the
/// UIKit appearance proxy once at launch.
@MainActor
enum CodeyNavigationTitles {
    static func apply() {
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: rounded(.largeTitle, bold: true)]
        bar.titleTextAttributes = [.font: rounded(.title2, bold: true)]
    }

    private static func rounded(_ style: UIFont.TextStyle, bold: Bool) -> UIFont {
        var descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
        if let roundedDescriptor = descriptor.withDesign(.rounded) { descriptor = roundedDescriptor }
        if bold, let boldDescriptor = descriptor.withSymbolicTraits(.traitBold) { descriptor = boldDescriptor }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
