import SwiftUI

/// Markdown field for card prompt/answer: TextEditor + formatting toolbar
/// (Bold, Italic, Code, List) + n/limit counter. Preview it with
/// CardMarkdownView.
struct MarkdownTextEditor: View {
    let title: String
    @Binding var text: String
    var limit: Int = ModelValidator.Limits.prompt.upperBound
    var errorMessage: String?

    @State private var selection: TextSelection?
    @FocusState private var isFocused: Bool

    private var count: Int { ModelValidator.measuredLength(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            TextEditor(text: $text, selection: $selection)
                .font(.codeyBody)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96)
                .padding(CodeySpacing.sm)
                .background(CodeyColor.fillNeutral, in: .codey(CodeyRadius.sm))
                .overlay {
                    if errorMessage != nil {
                        RoundedRectangle.codey(CodeyRadius.sm).strokeBorder(CodeyColor.danger, lineWidth: 1.5)
                    }
                }
                .accessibilityLabel(title)

            HStack(spacing: CodeySpacing.xs) {
                ForEach(MarkdownFormat.allCases, id: \.self) { format in
                    Button {
                        apply(format)
                    } label: {
                        Image(systemName: format.symbol)
                            .frame(minWidth: 36, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: CodeyRadius.xs))
                    .tint(CodeyColor.brand)
                    .accessibilityLabel(format.accessibilityLabel)
                }
                Spacer()
                Text("\(count)/\(limit)")
                    .font(.codeyCaption.monospacedDigit())
                    .foregroundStyle(count > limit ? CodeyColor.danger : CodeyColor.textSecondary)
                    .accessibilityLabel("\(count) of \(limit) characters")
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.codeyCaption)
                    .foregroundStyle(CodeyColor.danger)
            }
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
