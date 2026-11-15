import SwiftUI

/// A brand line icon on a soft brand tile (topic, deck and panel icons).
/// `size` is already Dynamic-Type scaled by the caller.
struct IconTile: View {
    let systemName: String
    let size: CGFloat
    var radius: CGFloat = CodeyRadius.md
    /// Ink and tile colors; a topic's hue on Play tiles (S41).
    var ink: Color = CodeyColor.brand
    var tile: Color = CodeyColor.brandSoft

    var body: some View {
        CodeyIcon.image(systemName)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.56, height: size * 0.56)
            .foregroundStyle(ink)
            .frame(width: size, height: size)
            .background(tile, in: .codey(radius))
            .accessibilityHidden(true)
    }
}
