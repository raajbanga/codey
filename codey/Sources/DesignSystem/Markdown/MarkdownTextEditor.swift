import SwiftUI

/// Markdown field for card prompt/answer: TextEditor + formatting toolbar
/// (Bold, Italic, Code, List) + n/limit counter. Preview it with
/// CardMarkdownView.
struct MarkdownTextEditor: View {
    let title: String
    @Binding var text: String
    var limit: Int = ModelValidator.Limits.prompt.upperBound
    var errorMessage: String?
    /// Set to true to move focus here (e.g. to the first invalid field after
    /// a failed save); reset to false once focused.
    var focusRequested: Binding<Bool> = .constant(false)

    @State private var selection: TextSelection?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            TextEditor(text: $text, selection: $selection)
                .font(.codeyBody)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96)
                .padding(CodeySpacing.sm)
                // A paper well with a hairline on the note, not a solid
                // grey block (§3b): the field reads as a page to write on.
                .background(CodeyColor.surface, in: .codey(CodeyRadius.md))
                .errorBorder(errorMessage != nil, radius: CodeyRadius.md)
                .accessibilityLabel(title)
                .onChange(of: focusRequested.wrappedValue, initial: true) { _, requested in
                    guard requested else { return }
                    isFocused = true
                    focusRequested.wrappedValue = false
                }

            HStack(spacing: CodeySpacing.xs) {
                ForEach(MarkdownFormat.allCases, id: \.self) { format in
                    Button {
                        apply(format)
                    } label: {
                        // Plain ink icons with a 44pt target: a quiet,
                        // editor-like toolbar (S9).
                        Image(systemName: format.symbol)
                            .foregroundStyle(CodeyColor.brand)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(format.accessibilityLabel)
                }
                Spacer()
                LimitCounter(count: ModelValidator.measuredLength(text), limit: limit)
            }

            FieldErrorLabel(message: errorMessage)
        }
    }

    private func apply(_ format: MarkdownFormat) {
        let range = selectedOffsets()
        let result = MarkdownFormatting.apply(format, to: text, selection: range)
        text = result.text
        let lower = text.index(text.startIndex, offsetBy: result.selection.lowerBound)
        let upper = text.index(text.startIndex, offsetBy: result.selection.upperBound)
        selection = TextSelection(range: lower..<upper)
        isFocused = true
    }

    private func selectedOffsets() -> Range<Int> {
        guard let selection, case .selection(let range) = selection.indices,
              range.lowerBound >= text.startIndex, range.upperBound <= text.endIndex else {
            return text.count..<text.count
        }
        let lower = text.distance(from: text.startIndex, to: range.lowerBound)
        let upper = text.distance(from: text.startIndex, to: range.upperBound)
        return lower..<upper
    }
}

extension MarkdownFormat {
    var symbol: String {
        switch self {
        case .bold: "bold"
        case .italic: "italic"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .bulletList: "list.bullet"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .bold: "Bold"
        case .italic: "Italic"
        case .code: "Inline code"
        case .bulletList: "Bulleted list"
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
