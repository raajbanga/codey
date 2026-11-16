import SwiftUI
import Testing
@testable import codey

/// Notion-style card text (§3b): closed markers fold away and their text
/// takes the style; the characters themselves never change.
@MainActor
struct MarkdownRichTextTests {
    private func font(of word: String, in text: AttributedString) -> Font? {
        text[text.range(of: word)!].runs.first!.font
    }

    @Test func charactersNeverChange() {
        let markdown = "Use **heap** or `stack` for _speed_\n- one\n- two"
        #expect(String(MarkdownRichText.styled(markdown).characters) == markdown)
    }

    @Test func closedPairsTakeTheirStyle() {
        let text = MarkdownRichText.styled("Use **heap** or `stack` for _speed_ and *size*")
        #expect(MarkdownRichText.Style.of(font(of: "heap", in: text)) == .bold)
        #expect(MarkdownRichText.Style.of(font(of: "stack", in: text)) == .code)
        #expect(MarkdownRichText.Style.of(font(of: "speed", in: text)) == .italic)
        #expect(MarkdownRichText.Style.of(font(of: "size", in: text)) == .italic)
        #expect(MarkdownRichText.Style.of(font(of: "Use", in: text)) == nil)
    }

    @Test func closedMarkersFoldAway() {
        let text = MarkdownRichText.styled("a **b** c")
        let marker = text[text.range(of: "**")!]
        #expect(marker.runs.first!.foregroundColor == .clear)
    }

    @Test func openMarkersStayVisible() {
        let text = MarkdownRichText.styled("a **half open")
        #expect(text[text.range(of: "**")!].runs.first!.foregroundColor == CodeyColor.textPrimary)
    }

    @Test func markersInsideCodeStayLiteral() {
        let text = MarkdownRichText.styled("`a **b** c`")
        #expect(MarkdownRichText.Style.of(font(of: "b", in: text)) == .code)
    }

    @Test func intrawordUnderscoresStayPlain() {
        let text = MarkdownRichText.styled("my_var_name")
        #expect(MarkdownRichText.Style.of(font(of: "var", in: text)) == nil)
    }

    @Test func listDashIsBrand() {
        let text = MarkdownRichText.styled("- one")
        #expect(text[text.range(of: "-")!].runs.first!.foregroundColor == CodeyColor.brand)
    }
}
