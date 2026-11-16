import SwiftUI

/// A symbol on a 44 pt circle, or a 32 pt one inside cards (S40): the app's icon-only button. One
/// component for close (neutral), the tab headers' buttons and Ask AI
/// (soft), and play / send (filled), so they share size, hit area, and
/// pressed state.
struct CircleIconButton: View {
    let systemImage: String
    let label: String
    var kind: CircleIcon.Kind = .neutral
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIcon(systemImage: systemImage, kind: kind, compact: compact)
        }
        .buttonStyle(TilePressStyle())
        .accessibilityLabel(label)
    }
}

/// The circle itself, for a NavigationLink's label (Groups on Play).
struct CircleIcon: View {
    enum Kind {
        /// ✕ and other quiet actions.
        case neutral
        /// Slate ink on the light slate pastel, in both modes (S41 two-tone):
        /// header buttons, Ask AI.
        case soft
        /// The brand fill (play, send): the strongest icon button.
        case filled
    }

    let systemImage: String
    var kind: Kind = .neutral
    /// Tag height (32 pt), for buttons beside tags inside a card (⋯, flip).
    /// The tap area stays 44 pt (HIG minimum).
    var compact = false

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appHue) private var appHue

    var body: some View {
        Icon(systemImage, size: compact ? 15 : 20, relativeTo: .headline)
            .foregroundStyle(colors.icon)
            .frame(width: compact ? 32 : 44, height: compact ? 32 : 44)
            .background(colors.fill, in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            // Compact lays out at tag height so it doesn't push its row
            // apart; the 44 pt tap area overhangs it.
            .padding(.vertical, compact ? -6 : 0)
            .opacity(isEnabled ? 1 : 0.45)
    }

    private var colors: (icon: Color, fill: Color) {
        switch kind {
        case .neutral: (CodeyColor.textSecondary, CodeyColor.fillNeutral)
        case .soft: ((appHue ?? .slate).ink, (appHue ?? .slate).soft)
        case .filled: appHue.map { (.white, $0.fill) } ?? (CodeyColor.onBrandFill, CodeyColor.brandFill)
        }
    }
}
