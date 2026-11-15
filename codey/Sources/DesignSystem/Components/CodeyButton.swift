import SwiftUI

/// The content-button roles.
enum CodeyButtonKind: Equatable {
    /// Pastel brand fill, ink label. One per screen: the main action.
    case primary
    /// Brand label on the soft brand tint.
    case secondary
    /// Danger label on its pastel fill.
    case destructive
    /// A topic's mid-tone fill with a white label (S41, Play tiles): the one
    /// strong action on a colored tile. palette.py checks the pair.
    case hue(CodeyColor.TopicHue)
}

/// The app's content button. Flat pastel fills, no glass: since Sprint 3
/// (S9) Liquid Glass is left to the system's own controls (tab bar,
/// toolbars, sheets). Labels are single-line (the Capsule rule, D19); long
/// text scales down rather than wrapping.
struct CodeyButton: View {
    let title: String
    var systemImage: String?
    var kind: CodeyButtonKind = .primary
    var fullWidth = false
    /// Smaller height and type, for buttons inside list rows.
    var compact = false
    let action: () -> Void

    @State private var taps = 0

    init(
        _ title: String,
        systemImage: String? = nil,
        kind: CodeyButtonKind = .primary,
        fullWidth: Bool = false,
        compact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
        self.fullWidth = fullWidth
        self.compact = compact
        self.action = action
    }

    var body: some View {
        Button(role: kind == .destructive ? .destructive : nil) {
            taps += 1
            action()
        } label: {
            HStack(spacing: CodeySpacing.sm) {
                if let systemImage {
                    Icon(systemImage, size: 18, relativeTo: .title2)
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(CodeyFillButtonStyle(kind: kind, compact: compact))
        .sensoryFeedback(kind == .destructive ? .warning : .impact(weight: .light), trigger: taps)
    }
}

/// Flat capsule with a pastel fill. Each fill/label pair is one that
/// scripts/palette checks at 4.5:1. Pressed state dims instead of scaling.
struct CodeyFillButtonStyle: ButtonStyle {
    let kind: CodeyButtonKind
    var compact = false
    /// Less side padding, for buttons in half-width tiles (S41).
    var tight = false

    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var regularHeight: CGFloat = 50
    @ScaledMetric(relativeTo: .subheadline) private var compactHeight: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .codeySubheadline.weight(.medium) : .codeyHeadline)
            .foregroundStyle(colors.label)
            .padding(.horizontal, tight ? CodeySpacing.md : compact ? CodeySpacing.md : CodeySpacing.lg)
            .frame(minHeight: compact ? compactHeight : regularHeight)
            .background(colors.fill, in: Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : (isEnabled ? 1 : 0.45))
            .animation(CodeyMotion.snappy, value: configuration.isPressed)
    }

    private var colors: (fill: Color, label: Color) {
        switch kind {
        case .primary: (CodeyColor.brandFill, CodeyColor.onBrandFill)
        case .secondary: (CodeyColor.brandSoft, CodeyColor.brand)
        case .destructive: (CodeyColor.Soft.danger, CodeyColor.danger)
        case .hue(let hue): (hue.fill, .white)
        }
    }
}
