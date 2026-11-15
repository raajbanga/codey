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
    /// What something pays: XP ink on XP soft, same in both modes (S41).
    case xp
    /// A status word on a topic's pastel ("Up next", "This week"): the
    /// pastel's ink, outlined, no fill.
    case outline(Color)

    /// Text/icon color; also the tint for anything themed by this variant.
    var color: Color {
        switch self {
        case .neutral: CodeyColor.textSecondary
        case .brand: CodeyColor.brand
        case .tier(let tier): tier.style.color
        case .success: CodeyColor.success
        case .warning: CodeyColor.warning
        case .danger: CodeyColor.danger
        case .xp: CodeyColor.xp
        case .outline(let color): color
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
        case .xp: CodeyColor.xpSoft
        case .outline: .clear
        }
    }

    var isOutline: Bool {
        if case .outline = self { return true }
        return false
    }
}

/// The app's one tag (S41): tier, status, XP, sync state, counts. Every
/// pill-shaped label is a CodeyChip so they share size, type, and padding.
/// Capsule is allowed because the text never wraps (lineLimit 1).
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

    /// "+10 XP" in XP gold.
    init(xp: Int) {
        self.init("+\(xp) XP", variant: .xp)
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
        .monospacedDigit()
        .background(variant.softColor, in: Capsule())
        .overlay {
            if variant.isOutline {
                Capsule().strokeBorder(variant.color.opacity(0.6), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if case .tier(let tier) = variant { return tier.style.accessibilityLabel }
        return title.replacingOccurrences(of: "+", with: "plus ")
    }
}
