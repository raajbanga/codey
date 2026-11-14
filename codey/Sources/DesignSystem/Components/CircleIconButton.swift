import SwiftUI

/// A symbol on a 44 pt circle (S40): the app's icon-only button. One
/// component for close (neutral), Ask AI (soft brand), and play / send
/// (brand fill), so they share size, hit area, and pressed state.
struct CircleIconButton: View {
    enum Kind {
        /// ✕ and other quiet actions.
        case neutral
        /// Brand ink on the soft brand tint (Ask AI).
        case soft
        /// The pastel brand fill (play, send): the strongest icon button.
        case filled
    }

    let systemImage: String
    let label: String
    var kind: Kind = .neutral
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Icon(systemImage, size: 20, relativeTo: .headline)
                .foregroundStyle(colors.icon)
                .frame(width: 44, height: 44)
                .background(colors.fill, in: Circle())
                .contentShape(Circle())
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var colors: (icon: Color, fill: Color) {
        switch kind {
        case .neutral: (CodeyColor.textSecondary, CodeyColor.fillNeutral)
        case .soft: (CodeyColor.brand, CodeyColor.brandSoft)
        case .filled: (CodeyColor.onBrandFill, CodeyColor.brandFill)
        }
    }
}
