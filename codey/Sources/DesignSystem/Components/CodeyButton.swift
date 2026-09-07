import SwiftUI

enum CodeyButtonVariant {
    case primary
    case secondary
    case outline
    case ghost
    case destructive
}

enum CodeyButtonSize {
    case sm
    case md
    case lg

    var verticalPadding: CGFloat {
        switch self {
        case .sm: CodeySpacing.sm
        case .md: CodeySpacing.sm + 2
        case .lg: CodeySpacing.md
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .sm: CodeySpacing.sm + 4
        case .md: CodeySpacing.md
        case .lg: CodeySpacing.lg
        }
    }

    var font: Font {
        switch self {
        case .sm: .caption.weight(.semibold)
        case .md: .subheadline.weight(.semibold)
        case .lg: .body.weight(.semibold)
        }
    }
}

struct CodeyButtonStyle: ButtonStyle {
    let variant: CodeyButtonVariant
    let size: CodeyButtonSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .foregroundStyle(foregroundColor(isPressed: configuration.isPressed))
            .background(backgroundColor(isPressed: configuration.isPressed))
            .overlay {
                if variant == .outline {
                    Capsule()
                        .stroke(ThemeColor.border, lineWidth: 1)
                }
            }
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return .white
        case .secondary:
            return ThemeColor.primary
        case .outline:
            return ThemeColor.primary
        case .ghost:
            return ThemeColor.primary
        case .destructive:
            return .white
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return ThemeColor.primary
        case .secondary:
            return ThemeColor.primary.opacity(0.12)
        case .outline:
            return .clear
        case .ghost:
            return isPressed ? ThemeColor.primary.opacity(0.08) : .clear
        case .destructive:
            return ThemeColor.destructive
        }
    }
}

struct CodeyButton: View {
    let title: String
    let variant: CodeyButtonVariant
    let size: CodeyButtonSize
    let action: () -> Void

    init(
        _ title: String,
        variant: CodeyButtonVariant = .primary,
        size: CodeyButtonSize = .md,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.size = size
        self.action = action
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
        }
        .buttonStyle(CodeyButtonStyle(variant: variant, size: size))
    }
}
