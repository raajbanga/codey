import SwiftUI

/// Codey's line icons (S40): hand-drawn 24 pt stroke SVGs from
/// scripts/icons/icons.py, looked up by the SF Symbol name the app already
/// uses (`CodeyIcon.assets`, generated), so stored names (Topic.iconName,
/// tier symbols) don't change. A name with no drawing falls back to the SF
/// Symbol.
enum CodeyIcon {
    /// The asset (template) or SF Symbol for `name`, for places that need a
    /// plain Image (Label, Tab).
    static func image(_ name: String) -> Image {
        if let asset = assets[name] { Image(asset).renderingMode(.template) } else { Image(systemName: name) }
    }
}

/// An icon sized from a text style, so it grows with Dynamic Type like the
/// text beside it. Decorative: pair it with text or an accessibility label.
struct Icon: View {
    let name: String
    @ScaledMetric private var size: CGFloat

    init(_ name: String, size: CGFloat = 20, relativeTo style: Font.TextStyle = .body) {
        self.name = name
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
    }

    var body: some View {
        CodeyIcon.image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

extension Label where Title == Text, Icon == Image {
    /// A Label with a Codey line icon (or the SF Symbol fallback).
    init(_ title: some StringProtocol, icon name: String) {
        self.init { Text(title) } icon: { CodeyIcon.image(name) }
    }
}
