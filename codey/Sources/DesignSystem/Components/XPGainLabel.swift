import SwiftUI

/// One XP award, e.g. +25 with "Medium 15 + streak 10".
struct XPGain: Equatable, Identifiable {
    let id = UUID()
    let amount: Int
    var breakdown: String?
}

/// Rolling XP total. Since Sprint 3 (S9) there's no floating "+25 XP":
/// the quiz feedback card already states the gain, so the total just rolls.
struct XPGainLabel: View {
    let total: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CodeySpacing.xs) {
            Text(total, format: .number)
                .font(.codeyNumericSmall)
                .contentTransition(.numericText(value: Double(total)))
            Text("XP")
                .font(.codeyCaption.weight(.medium))
                .foregroundStyle(CodeyColor.textSecondary)
        }
        .codeyAnimation(CodeyMotion.snappy, value: total)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(total) XP")
    }
}
