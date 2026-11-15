import SwiftUI

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

/// Notion-style card text (§3b, Nov 15). The editor's text is the card's
/// Markdown, character for character, but once a pair closes (`**x**`,
/// `_x_`, `*x*`, `` `x` ``) the inside takes the style and the markers fold
/// away to nothing, so bold just looks bold. Only attributes change, never
/// characters, so restyling while you type can't move the caret or race the
/// keyboard. A list's `- ` shows as a bold brand dash.
@MainActor
enum MarkdownRichText {
    enum Style: CaseIterable {
        case bold, italic, code

        var font: Font {
            switch self {
            case .bold: Font.codeyBody.bold()
            case .italic: Font.codeyBody.italic()
            case .code: Font.codeyCode
            }
        }

        static func of(_ font: Font?) -> Style? { allCases.first { $0.font == font } }
    }

    /// Code first: markers inside a code span stay literal.
    private static let rules: [(NSRegularExpression, Style)] = ([
        (#"(`)([^`\n]+)(`)"#, .code),
        (#"(\*\*)([^*\n]+?)(\*\*)"#, .bold),
        (#"(?<![\w*])(\*)([^*\s][^*\n]*?)(\*)(?![\w*])"#, .italic),
        (#"(?<!\w)(_)([^_\s][^_\n]*?)(_)(?!\w)"#, .italic),
    ] as [(String, Style)]).map { (try! NSRegularExpression(pattern: $0.0), $0.1) }
    private static let listMarker = try! NSRegularExpression(pattern: #"(?m)^[-*](?= )"#)

    /// A folded marker: no width, no ink.
    static let folded = AttributeContainer().font(.system(size: 0.1)).foregroundColor(.clear)

    static func styled(_ markdown: String) -> AttributedString {
        var text = AttributedString(markdown)
        apply(to: &text)
        return text
    }

    /// Restyles all of `text` from its characters.
    static func apply(to text: inout AttributedString) {
        let full = text.startIndex..<text.endIndex
        text[full].font = Font.codeyBody
        text[full].foregroundColor = CodeyColor.textPrimary
        text[full].backgroundColor = nil

        let plain = String(text.characters)
        let whole = NSRange(plain.startIndex..., in: plain)
        var taken = IndexSet()
        for (regex, style) in rules {
            for match in regex.matches(in: plain, range: whole) {
                let span = match.range.location..<(match.range.location + match.range.length)
                guard !taken.intersects(integersIn: span),
                      let inner = range(match.range(at: 2), in: text, plain),
                      let open = range(match.range(at: 1), in: text, plain),
                      let close = range(match.range(at: 3), in: text, plain) else { continue }
                taken.insert(integersIn: span)
                text[inner].font = style.font
                if style == .code { text[inner].backgroundColor = CodeyColor.brandSoft }
                text[open].mergeAttributes(folded)
                text[close].mergeAttributes(folded)
            }
        }
        for match in listMarker.matches(in: plain, range: whole) {
            guard let dash = range(match.range, in: text, plain) else { continue }
            text[dash].font = Font.codeyBody.bold()
            text[dash].foregroundColor = CodeyColor.brand
        }
    }

    private static func range(_ range: NSRange, in text: AttributedString, _ plain: String) -> Range<AttributedString.Index>? {
        guard let r = Range(range, in: plain) else { return nil }
        let start = text.characters.index(text.startIndex, offsetBy: plain.distance(from: plain.startIndex, to: r.lowerBound))
        return start..<text.characters.index(start, offsetBy: plain.distance(from: r.lowerBound, to: r.upperBound))
    }
}
