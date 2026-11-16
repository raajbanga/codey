import SwiftUI

/// A small one-of-several choice drawn as the app's own buttons
/// (`CodeyFillButtonStyle`), in place of the system segmented control.
///
///     [■ Quizzes]  [□ Exercises]
///
///     [■ Mixed ] [□ Easy  ]       ← four or more: two to a row
///     [□ Medium] [□ Hard  ]
///
/// The chosen one is a primary button, the others secondary, at full
/// button height so their corners match Start / Continue (Nov 15). A
/// choice looks like every other button (§3b, Nov 15: no outlined white pills).
/// Each is a button with the Selected trait, so VoiceOver and UI tests
/// find them by title.
struct ChoiceChips<Value: Hashable>: View {
    let label: String
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    /// Equal-width buttons across the whole row (Decks filter, theme).
    var fills = false

    init(_ label: String, selection: Binding<Value>, options: [(value: Value, title: String)], fills: Bool = false) {
        self.label = label
        _selection = selection
        self.options = options
        self.fills = fills
    }

    /// At most three in a row (Nov 15); four or more go two to a row.
    static var maxPerRow: Int { 3 }

    var body: some View {
        Group {
            if options.count <= Self.maxPerRow {
                HStack(spacing: CodeySpacing.xs) { buttons(fill: fills) }
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: CodeySpacing.xs), count: 2),
                    spacing: CodeySpacing.xs
                ) { buttons(fill: true) }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

extension ChoiceChips {
    fileprivate func buttons(fill: Bool) -> some View {
        ForEach(options, id: \.value) { option in
            let chosen = option.value == selection
            Button { selection = option.value } label: {
                Text(option.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: fill ? .infinity : nil)
            }
            .buttonStyle(CodeyFillButtonStyle(kind: chosen ? .primary : .secondary, tight: true))
            .accessibilityAddTraits(chosen ? .isSelected : [])
        }
    }
}

extension ChoiceChips where Value: CaseIterable & RawRepresentable<String>, Value.AllCases: RandomAccessCollection {
    /// Every case, titled by its raw value.
    init(_ label: String, selection: Binding<Value>, fills: Bool = false) {
        self.init(label, selection: selection, options: Value.allCases.map { ($0, $0.rawValue) }, fills: fills)
    }
}
