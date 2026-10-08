import SwiftUI

/// Type tokens. All are Dynamic Type text styles; headings and numbers use
/// SF Rounded (D12).
extension Font {
    static let codeyDisplay = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let codeyTitle = Font.system(.title2, design: .rounded, weight: .semibold)
    static let codeyHeadline = Font.headline
    static let codeyBody = Font.body
    static let codeyCallout = Font.callout
    static let codeySubheadline = Font.subheadline
    static let codeyCaption = Font.caption
    /// XP, levels, counters. Pair with .contentTransition(.numericText()).
    static let codeyNumeric = Font.system(.title, design: .rounded, weight: .bold).monospacedDigit()
    static let codeyNumericSmall = Font.system(.headline, design: .rounded, weight: .semibold).monospacedDigit()
}
