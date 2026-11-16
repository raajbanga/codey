import SwiftUI

/// Card prompt / answer field, Notion-style (§3b, Nov 15): you type
/// straight on the card, with no grey well, and a closed `**x**` or
/// `` `x` `` shows as bold or code with its markers folded away
/// (MarkdownRichText). The format
/// row (Bold, Italic, Code, List) appears under the text only while you
/// type, and the n/limit counter only once you're near the limit. The
/// binding stays Markdown.
struct MarkdownTextEditor: View {
    let title: String
    @Binding var text: String
    var limit: Int = ModelValidator.Limits.prompt.upperBound
    var errorMessage: String?
    /// Set to true to move focus here (e.g. to the first invalid field after
    /// a failed save); reset to false once focused.
    var focusRequested: Binding<Bool> = .constant(false)

    @State private var rich = AttributedString()
    @State private var selection = AttributedTextSelection()
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var length: Int { ModelValidator.measuredLength(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            TextEditor(text: $rich, selection: $selection)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(minHeight: 120, alignment: .topLeading)
                // TextEditor insets its text; pull it back to the card's edge.
                .padding(.horizontal, -CodeySpacing.xs)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Type the \(title.lowercased())…")
                            .font(.codeyBody)
                            .foregroundStyle(CodeyColor.textSecondary)
                            .padding(.top, CodeySpacing.xs)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(title)
                .onAppear { rich = MarkdownRichText.styled(text) }
                .onChange(of: rich) { _, new in
                    let plain = String(new.characters)
                    guard plain != text else { return }
                    text = plain
                    // Attributes only: the caret and the keyboard's pending
                    // input are left alone.
                    MarkdownRichText.apply(to: &rich)
                }
                .onChange(of: text) { _, new in
                    // Changed from outside (a reset, an undo): restyle all.
                    if String(rich.characters) != new { rich = MarkdownRichText.styled(new) }
                }
                .onChange(of: focusRequested.wrappedValue, initial: true) { _, requested in
                    guard requested else { return }
                    isFocused = true
                    focusRequested.wrappedValue = false
                }

            if isFocused || length * 5 >= limit * 4 {
                HStack(spacing: 0) {
                    if isFocused { formatButtons }
                    Spacer(minLength: 0)
                    if length * 5 >= limit * 4 { LimitCounter(count: length, limit: limit) }
                }
                .transition(.opacity)
            }

            FieldErrorLabel(message: errorMessage)
        }
        .animation(CodeyMotion.resolve(CodeyMotion.snappy, reduceMotion: reduceMotion), value: isFocused)
    }

    private var formatButtons: some View {
        ForEach(MarkdownFormat.allCases, id: \.self) { format in
            Button { apply(format) } label: {
                Image(systemName: format.symbol)
                    .foregroundStyle(CodeyColor.brand)
                    .frame(minWidth: 44, minHeight: 36)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(format.accessibilityLabel)
        }
    }

    /// Wraps (or unwraps) the selection in the format's markers; with no
    /// selection, an empty pair with the caret inside, so what you type next
    /// takes the style once you close it.
    private func apply(_ format: MarkdownFormat) {
        let result = MarkdownFormatting.apply(format, to: text, selection: selectedOffsets())
        text = result.text
        rich = MarkdownRichText.styled(result.text)
        let lower = rich.characters.index(rich.startIndex, offsetBy: result.selection.lowerBound)
        let upper = rich.characters.index(rich.startIndex, offsetBy: result.selection.upperBound)
        selection = AttributedTextSelection(range: lower..<upper)
        isFocused = true
    }

    /// The selection as Character offsets (MarkdownFormatting's units).
    private func selectedOffsets() -> Range<Int> {
        func offset(_ index: AttributedString.Index) -> Int {
            rich.characters.distance(from: rich.startIndex, to: index)
        }
        switch selection.indices(in: rich) {
        case .insertionPoint(let index):
            return offset(index)..<offset(index)
        case .ranges(let ranges):
            guard let first = ranges.ranges.first, let last = ranges.ranges.last else { return 0..<0 }
            return offset(first.lowerBound)..<offset(last.upperBound)
        }
    }
}

#Preview("Markdown editor") {
    @Previewable @State var text = "What does `defer` do?"
    VStack(alignment: .leading) {
        MarkdownTextEditor(title: "Prompt", text: $text)
        CardMarkdownView(markdown: text)
    }
    .padding()
}
