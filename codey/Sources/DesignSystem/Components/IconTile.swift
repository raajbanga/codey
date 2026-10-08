import SwiftUI

/// A brand symbol on a soft brand tile (topic and deck icons).
struct IconTile: View {
    let systemName: String
    let size: CGFloat
    var font: Font = .codeyTitle
    var radius: CGFloat = CodeyRadius.md

    var body: some View {
        Image(systemName: systemName)
            .font(font)
            .foregroundStyle(CodeyColor.brand)
            .frame(width: size, height: size)
            .background(CodeyColor.brandSoft, in: .codey(radius))
            .accessibilityHidden(true)
    }
}
