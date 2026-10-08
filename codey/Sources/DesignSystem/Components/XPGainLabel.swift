import SwiftUI

/// One XP award, e.g. +25 with "Medium 15 + streak 10".
struct XPGain: Equatable, Identifiable {
    let id = UUID()
    let amount: Int
    var breakdown: String?
}

/// Rolling XP total with a "+25 XP" that floats up and fades on each gain.
struct XPGainLabel: View {
    let total: Int
    var lastGain: XPGain?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating: XPGain?
    @State private var rise: CGFloat = 0
    @State private var fade: Double = 1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CodeySpacing.xs) {
            Text(total, format: .number)
                .font(.codeyNumericSmall)
                .contentTransition(.numericText(value: Double(total)))
            Text("XP")
                .font(.codeyCaption.weight(.semibold))
                .foregroundStyle(CodeyColor.textSecondary)
        }
        .codeyAnimation(CodeyMotion.snappy, value: total)
        .overlay(alignment: .top) {
            if let floating {
                VStack(spacing: 0) {
                    Text("+\(floating.amount) XP")
                        .font(.codeyNumericSmall)
                        .foregroundStyle(CodeyColor.success)
                    if let breakdown = floating.breakdown {
                        Text(breakdown)
                            .font(.codeyCaption)
                            .foregroundStyle(CodeyColor.textSecondary)
                    }
                }
                .fixedSize()
                .offset(y: -24 + rise)
                .opacity(fade)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .onChange(of: lastGain) { _, gain in
            guard let gain, gain.amount > 0 else { return }
            float(gain)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(total) XP")
    }

    private func float(_ gain: XPGain) {
        floating = gain
        rise = 0
        fade = 1
        withAnimation(.easeOut(duration: reduceMotion ? 0.6 : 1.0)) {
            if !reduceMotion { rise = -24 }
            fade = 0
        } completion: {
            if floating?.id == gain.id { floating = nil }
        }
    }
}
