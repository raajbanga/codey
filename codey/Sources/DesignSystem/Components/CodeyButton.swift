import SwiftUI

enum CodeyButtonKind {
    /// Solid brand fill, white label. In content.
    case primary
    /// Tinted brand label on a soft fill. In content.
    case secondary
    /// Liquid Glass, brand tint. Floating over content (toolbars, pinned CTAs).
    case glassPrimary
    /// Liquid Glass, neutral. Floating over content.
    case glassSecondary
    /// Danger label on a soft danger fill (white on dark-mode red fails 4.5:1).
    case destructive
}

/// Thin wrapper over the native button styles: it only adds haptics and the
/// Capsule shape. Labels are single-line (the
/// Capsule rule, D19); long text scales down rather than wrapping.
struct CodeyButton: View {
    let title: String
    var systemImage: String?
    var kind: CodeyButtonKind = .primary
    var fullWidth = false
    let action: () -> Void

    @State private var taps = 0

    init(
        _ title: String,
        systemImage: String? = nil,
        kind: CodeyButtonKind = .primary,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button(role: kind == .destructive ? .destructive : nil) {
            taps += 1
            action()
        } label: {
            HStack(spacing: CodeySpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .fontWeight(.semibold)
            .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .modifier(KindStyle(kind: kind))
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .sensoryFeedback(kind == .destructive ? .warning : .impact(weight: .light), trigger: taps)
    }

    private struct KindStyle: ViewModifier {
        let kind: CodeyButtonKind

        func body(content: Content) -> some View {
            switch kind {
            case .primary:
                content.buttonStyle(.borderedProminent).tint(CodeyColor.brandFill)
            case .secondary:
                content.buttonStyle(.bordered).tint(CodeyColor.brand)
            case .glassPrimary:
                content.buttonStyle(.glassProminent).tint(CodeyColor.brandFill)
            case .glassSecondary:
                content.buttonStyle(.glass)
            case .destructive:
                content.buttonStyle(.bordered).tint(CodeyColor.danger)
            }
        }
    }
}
