import SwiftUI

/// Animated linear progress (replaces CodeyProgress). A thin 4pt line since
/// Sprint 3 (S9); fixed height, so a Capsule is fine here.
struct ProgressBar: View {
    let value: Double
    var label: String?
    var tint: Color = CodeyColor.brand
    /// 4 pt by default; the level bar on Play is thicker (S41).
    var height: CGFloat = 4
    /// The paper-dot ink by default; a colored card passes its own tint.
    var track: Color = CodeyColor.paperDot

    @State private var shown: Double = 0

    init(value: Double, label: String? = nil, tint: Color = CodeyColor.brand, height: CGFloat = 4, track: Color = CodeyColor.paperDot) {
        self.value = min(max(value, 0), 1)
        self.label = label
        self.tint = tint
        self.height = height
        self.track = track
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            if let label {
                Text(label)
                    .font(.codeyCaption)
                    .foregroundStyle(CodeyColor.textSecondary)
            }
            // Track in the dot-grid ink, which reads on paper and on white
            // tiles alike (FillNeutral was nearly invisible on both, S40).
            Capsule()
                .fill(track)
                .frame(height: height)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(tint)
                            .frame(width: max(proxy.size.width * shown, shown > 0 ? height : 0))
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
