import SwiftUI

/// Circular progress with rounded caps (level ring). Optional center content.
struct ProgressRing<Center: View>: View {
    let value: Double
    var lineWidth: CGFloat = 8
    var tint: Color = CodeyColor.brand
    @ViewBuilder var center: Center

    @State private var shown: Double = 0

    init(value: Double, lineWidth: CGFloat = 8, tint: Color = CodeyColor.brand, @ViewBuilder center: () -> Center) {
        self.value = min(max(value, 0), 1)
        self.lineWidth = lineWidth
        self.tint = tint
        self.center = center()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(CodeyColor.fillNeutral, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center
        }
        .padding(lineWidth / 2)
        .onAppear { shown = value }
        .onChange(of: value) { _, new in shown = new }
        .codeyAnimation(CodeyMotion.smooth, value: shown)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

extension ProgressRing where Center == EmptyView {
    init(value: Double, lineWidth: CGFloat = 8, tint: Color = CodeyColor.brand) {
        self.init(value: value, lineWidth: lineWidth, tint: tint) { EmptyView() }
    }
}
