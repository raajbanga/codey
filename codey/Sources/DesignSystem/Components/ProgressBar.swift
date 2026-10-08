import SwiftUI

/// Animated linear progress (replaces CodeyProgress). Fixed 8pt height, so a
/// Capsule is fine here.
struct ProgressBar: View {
    let value: Double
    var label: String?
    var tint: Color = CodeyColor.brand

    @State private var shown: Double = 0

    init(value: Double, label: String? = nil, tint: Color = CodeyColor.brand) {
        self.value = min(max(value, 0), 1)
        self.label = label
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            if let label {
                Text(label)
                    .font(.codeyCaption)
                    .foregroundStyle(CodeyColor.textSecondary)
            }
            Capsule()
                .fill(CodeyColor.fillNeutral)
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(tint)
                            .frame(width: max(proxy.size.width * shown, shown > 0 ? 8 : 0))
                    }
                }
                .clipShape(Capsule())
        }
        .onAppear { shown = value }
        .onChange(of: value) { _, new in shown = new }
        .codeyAnimation(CodeyMotion.smooth, value: shown)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Progress")
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}
