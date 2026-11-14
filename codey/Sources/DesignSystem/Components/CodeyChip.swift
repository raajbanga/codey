import SwiftUI

/// Chip color roles. Tier chips also carry a symbol and label, so meaning
/// never rests on color alone (NFR-12).
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

    /// The pastel fill behind `color` (a pair scripts/palette checks).
    var softColor: Color {
        switch self {
        case .neutral: CodeyColor.fillNeutral
        case .brand: CodeyColor.brandSoft
        case .tier(.easy): CodeyColor.Soft.easy
        case .tier(.medium): CodeyColor.Soft.medium
        case .tier(.hard): CodeyColor.Soft.hard
        case .success: CodeyColor.Soft.success
        case .warning: CodeyColor.Soft.warning
        case .danger: CodeyColor.Soft.danger
        }
    }
}

/// Single-line pill for status, tier, and counts. Capsule is allowed here
/// because the text never wraps (lineLimit 1, scales down instead).
struct CodeyChip: View {
    let title: String
    var systemImage: String?
    var variant: CodeyChipVariant = .neutral

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
                Icon(systemImage, size: 13, relativeTo: .caption)
            }
            // An empty title makes an icon-only chip (compact tier chips).
            if !title.isEmpty {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .font(.codeyCaption.weight(.medium))
        .foregroundStyle(variant.color)
        .padding(.horizontal, title.isEmpty ? CodeySpacing.sm : CodeySpacing.sm + CodeySpacing.xxs)
        .padding(.vertical, CodeySpacing.xs)
        .background(variant.softColor, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if case .tier(let tier) = variant { return tier.style.accessibilityLabel }
        return title
    }
}
