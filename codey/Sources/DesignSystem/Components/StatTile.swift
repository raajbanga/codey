import SwiftUI

/// Stat tiles side by side, stacked when they don't fit (large text).
struct StatTileRow<Tiles: View>: View {
    @ViewBuilder let tiles: Tiles

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CodeySpacing.sm) { tiles }
            VStack(spacing: CodeySpacing.sm) { tiles }
        }
    }
}

/// A big rounded number that rolls when it changes, plus a label.
struct StatTile: View {
    let value: Int
    let label: String
    var suffix: String?
    var systemImage: String?
    var tint: Color = CodeyColor.brand

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.codeyHeadline)
                    .foregroundStyle(tint)
            }
            HStack(alignment: .firstTextBaseline, spacing: CodeySpacing.xxs) {
                Text(value, format: .number)
                    .font(.codeyNumeric)
                    .contentTransition(.numericText(value: Double(value)))
                if let suffix {
                    Text(suffix)
                        .font(.codeyNumericSmall)
                }
            }
            .foregroundStyle(CodeyColor.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text(label)
                .font(.codeyCaption)
                .foregroundStyle(CodeyColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CodeySpacing.md)
        .background(CodeyColor.surfaceRaised, in: .codey(CodeyRadius.md))
        .codeyAnimation(CodeyMotion.snappy, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value.formatted())\(suffix ?? "")")
    }
}
