import SwiftUI
import Textual

/// THE place card content renders (builder preview, study, quiz prompts,
/// starter browsing). Block markdown via Textual, with the optional snippet
/// as a Prism-highlighted code block. Only this file imports Textual (R12):
/// a swap to MarkdownUI stays local.
struct CardMarkdownView: View {
    let markdown: String
    var snippet: CodeSnippet?

    var body: some View {
        StructuredText(markdown: CardMarkdownComposition.compose(markdown: markdown, snippet: snippet))
            .font(.codeyBody)
            .foregroundStyle(CodeyColor.textPrimary)
            .textual.inlineStyle(Self.inlineStyle)
            .textual.codeBlockStyle(CodeyCodeBlockStyle())
            .textual.highlighterTheme(Self.highlighterTheme)
            .textual.textSelection(.enabled)
    }

    private static let inlineStyle = InlineStyle.default
        .code(.monospaced, .fontScale(0.92), .backgroundColor(DynamicColor(CodeyColor.brandSoft)))
        .link(.foregroundColor(DynamicColor(CodeyColor.brand)), .underlineStyle(.single))

    private static let highlighterTheme = StructuredText.HighlighterTheme(
        foregroundColor: DynamicColor(SyntaxRole.plain.color),
        backgroundColor: DynamicColor(CodeyColor.Syntax.background),
        tokenProperties: Dictionary(
            uniqueKeysWithValues: SyntaxRole.prismTokens.map { token, role in
                (StructuredText.HighlighterTheme.TokenType(rawValue: token), AnyTextProperty(.foregroundColor(DynamicColor(role.color))))
            }
        )
    )
}

/// Code block: language label + copy button header, horizontal scroll (no
/// wrapping), inset code background, md radius.
private struct CodeyCodeBlockStyle: StructuredText.CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CodeBlockHeader(
                language: CodeLanguage(fenceHint: configuration.languageHint)?.displayName
                    ?? configuration.languageHint?.capitalized ?? "Code",
                copy: { configuration.codeBlock.copyToPasteboard() }
            )
            Overflow {
                configuration.label
                    .monospaced()
                    .textual.fontScale(0.88)
                    .textual.lineSpacing(.fontScaled(0.2))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CodeySpacing.md)
                    .padding(.bottom, CodeySpacing.md)
                    .padding(.top, CodeySpacing.xs)
            }
        }
        .background(CodeyColor.Syntax.background, in: .codey(CodeyRadius.md))
        .textual.blockSpacing(.init(top: CodeySpacing.xs, bottom: CodeySpacing.md))
    }
}

private struct CodeBlockHeader: View {
    let language: String
    let copy: () -> Void
    @State private var copied = false

    var body: some View {
        HStack {
            Text(language)
                .font(.codeyCaption.weight(.semibold))
                .foregroundStyle(CodeyColor.textSecondary)
            Spacer()
            Button {
                copy()
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(minWidth: 44, minHeight: 32)
            }
            .buttonStyle(.borderless)
            .tint(CodeyColor.textSecondary)
            .accessibilityLabel(copied ? "Copied" : "Copy code")
            .sensoryFeedback(.success, trigger: copied) { _, new in new }
        }
        .padding(.leading, CodeySpacing.md)
        .padding(.trailing, CodeySpacing.xs)
        .padding(.top, CodeySpacing.xxs)
    }
}

#Preview("Card markdown") {
    ScrollView {
        CardMarkdownView(
            markdown: "What does `defer` do in **Swift**?\n\n- Runs at scope exit\n- Even on `throw`",
            snippet: CodeSnippet(language: .swift, source: """
                func read(_ url: URL) throws -> Data {
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() } // always runs
                    return try handle.readToEnd() ?? Data()
                }
                """)
        )
        .padding()
    }
}
