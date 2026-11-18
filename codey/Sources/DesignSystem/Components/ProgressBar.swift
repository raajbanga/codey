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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            // The fill is a shape whose only animated value is the fraction,
            // so it always grows from the left edge, never with the layout.
            Capsule()
                .fill(track)
                .overlay {
                    ProgressFill(fraction: shown)
                        .fill(tint)
                        .animation(reduceMotion ? nil : CodeyMotion.smooth, value: shown)
                }
                .frame(height: height)
        }
        .onAppear { shown = value }
        .onChange(of: value) { _, new in shown = new }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Progress")
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

/// The filled part of a ProgressBar: a capsule from the leading edge to
/// `fraction` of the width (at least round at a sliver).
private struct ProgressFill: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard fraction > 0 else { return Path() }
        let width = min(max(rect.width * fraction, rect.height), rect.width)
        return Capsule().path(in: CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height))
    }
}
