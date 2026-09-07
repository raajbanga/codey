import SwiftUI

struct CodeyProgress: View {
    let value: Double
    let label: String?

    @State private var animatedValue: Double = 0

    init(value: Double, label: String? = nil) {
        self.value = min(max(value, 0), 1)
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(ThemeColor.muted)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ThemeColor.border.opacity(0.4))
                        .frame(height: 8)

                    Capsule()
                        .fill(ThemeColor.primary)
                        .frame(width: geometry.size.width * animatedValue, height: 8)
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedValue = newValue
            }
        }
    }
}
