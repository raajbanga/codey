import SwiftUI

/// The app's glyph: a terminal prompt in ink on a pastel brand tile. Used by the launch
/// screen and onboarding.
struct AppGlyph: View {
    var size: CGFloat = 96

    var body: some View {
        Image(systemName: "chevron.left.forwardslash.chevron.right")
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(CodeyColor.onBrandFill)
            .frame(width: size, height: size)
            .background(CodeyColor.brandFill, in: .codey(size * 0.225))
            .accessibilityHidden(true)
    }
}
