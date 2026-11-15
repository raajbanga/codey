import SwiftUI

/// A small one-of-several choice drawn as the app's pills (S40), in place
/// of the system segmented control, whose gray track and sliding thumb
/// matched nothing else on the notebook paper.
///
///     (● Quizzes)  ( Exercises )
///
/// S41: 44 pt pills. The chosen one is the brand fill (as the primary
/// button); the others are white notes with an outline, so all read on
/// the paper. Each pill is a button with the Selected trait, so VoiceOver
/// and UI tests find them by title.
struct ChoiceChips<Value: Hashable>: View {
    let label: String
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    /// Equal-width pills across the whole row (S41: Decks filter, theme).
    var fills = false

    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = 44

    init(_ label: String, selection: Binding<Value>, options: [(value: Value, title: String)], fills: Bool = false) {
        self.label = label
        _selection = selection
        self.options = options
        self.fills = fills
    }

    var body: some View {
        HStack(spacing: CodeySpacing.xs) {
            ForEach(options, id: \.value) { option in
                let chosen = option.value == selection
                Button(option.title) { selection = option.value }
                    .font(.codeyCallout.weight(.semibold))
                    .foregroundStyle(chosen ? CodeyColor.onBrandFill : CodeyColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, fills ? CodeySpacing.sm : CodeySpacing.lg)
                    .frame(maxWidth: fills ? .infinity : nil, minHeight: height)
                    .background(chosen ? CodeyColor.brandFill : CodeyColor.surfaceRaised, in: Capsule())
                    .overlay { Capsule().strokeBorder(chosen ? CodeyColor.brand.opacity(0.35) : CodeyColor.separator, lineWidth: 1.5) }
                    .contentShape(.capsule)
                    .padding(.vertical, CodeySpacing.xxs)
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

extension ChoiceChips where Value: CaseIterable & RawRepresentable<String>, Value.AllCases: RandomAccessCollection {
    /// Every case, titled by its raw value.
    init(_ label: String, selection: Binding<Value>, fills: Bool = false) {
        self.init(label, selection: selection, options: Value.allCases.map { ($0, $0.rawValue) }, fills: fills)
    }
}
