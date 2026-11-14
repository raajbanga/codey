import SwiftUI

/// A brand line icon on a soft brand tile (topic, deck and panel icons).
/// `size` is already Dynamic-Type scaled by the caller.
struct IconTile: View {
    let systemName: String
    let size: CGFloat
    var radius: CGFloat = CodeyRadius.md

    var body: some View {
        CodeyIcon.image(systemName)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.56, height: size * 0.56)
            .foregroundStyle(CodeyColor.brand)
            .frame(width: size, height: size)
            .background(CodeyColor.brandSoft, in: .codey(radius))
            .accessibilityHidden(true)
    }
}
