import SwiftUI

/// A symbol on a 44 pt circle (S40): the app's icon-only button. One
/// component for close (neutral), the tab headers' buttons and Ask AI
/// (soft), and play / send (filled), so they share size, hit area, and
/// pressed state.
struct CircleIconButton: View {
    let systemImage: String
    let label: String
    var kind: CircleIcon.Kind = .neutral
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIcon(systemImage: systemImage, kind: kind)
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

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appHue) private var appHue

    var body: some View {
        Icon(systemImage, size: 20, relativeTo: .headline)
            .foregroundStyle(colors.icon)
            .frame(width: 44, height: 44)
            .background(colors.fill, in: Circle())
            .contentShape(Circle())
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
