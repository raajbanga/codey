import SwiftUI

enum CodeyBadgeVariant {
    case success
    case neutral
    case warning

    var foregroundColor: Color {
        switch self {
        case .success: ThemeColor.success
        case .neutral: ThemeColor.muted
        case .warning: ThemeColor.warning
        }
    }

    var backgroundColor: Color {
        foregroundColor.opacity(0.15)
    }
}

struct CodeyBadge: View {
    let text: String
    let variant: CodeyBadgeVariant

    init(_ text: String, variant: CodeyBadgeVariant = .neutral) {
        self.text = text
        self.variant = variant
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(variant.foregroundColor)
            .padding(.horizontal, CodeySpacing.sm + 2)
            .padding(.vertical, CodeySpacing.xs)
            .background(variant.backgroundColor)
            .clipShape(Capsule())
    }
}
