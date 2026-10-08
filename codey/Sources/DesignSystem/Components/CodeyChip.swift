import SwiftUI

enum CodeyChipVariant: Equatable {
    case neutral
    case brand
    case tier(Difficulty)
    case success
    case warning
    case danger

    /// Text/icon color; also the tint for anything themed by this variant.
    var color: Color {
        switch self {
        case .neutral: CodeyColor.textSecondary
        case .brand: CodeyColor.brand
        case .tier(let tier): tier.style.color
        case .success: CodeyColor.success
        case .warning: CodeyColor.warning
        case .danger: CodeyColor.danger
        }
    }
}

/// Single-line pill for status, tier, and counts. Capsule is allowed here
/// because the text never wraps (lineLimit 1, scales down instead).
struct CodeyChip: View {
    let title: String
    var systemImage: String?
    var variant: CodeyChipVariant = .neutral

    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, systemImage: String? = nil, variant: CodeyChipVariant = .neutral) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
    }

    /// A tier chip: tier color + tier symbol + label (never color alone).
    init(tier: Difficulty) {
        self.init(tier.style.label, systemImage: tier.style.symbol, variant: .tier(tier))
    }

    var body: some View {
        HStack(spacing: CodeySpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.codeyCaption.weight(.semibold))
        .foregroundStyle(variant.color)
        .padding(.horizontal, CodeySpacing.sm + CodeySpacing.xxs)
        .padding(.vertical, CodeySpacing.xs)
        .background(background, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var background: Color {
        switch variant {
        case .neutral: CodeyColor.fillNeutral
        case .brand: CodeyColor.brandSoft
        default: CodeyColor.softFill(variant.color, for: colorScheme)
        }
    }

    private var accessibilityText: String {
        if case .tier(let tier) = variant { return tier.style.accessibilityLabel }
        return title
    }
}
