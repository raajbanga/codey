import Foundation

/// Builds the one markdown document a card renders: its text plus, if it has
/// one, its code snippet as a fenced block (D2). Pure, so it's unit-tested
/// without Textual.
enum CardMarkdownComposition {
    static func compose(markdown: String, snippet: CodeSnippet?) -> String {
        guard let snippet else { return markdown }
        let fence = fence(for: snippet.source)
        // The raw value is also the Prism grammar name (Prism says "cpp", not "c++").
        let block = "\(fence)\(snippet.language.rawValue)\n\(snippet.source)\n\(fence)"
        let text = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? block : "\(text)\n\n\(block)"
    }

    /// A backtick fence longer than any backtick run in `source` (minimum 3),
    /// so code that itself contains ``` can't close the block early.
    static func fence(for source: String) -> String {
        var longest = 0
        var current = 0
        for character in source {
            if character == "`" {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return String(repeating: "`", count: max(3, longest + 1))
    }
}

extension CodeLanguage {
    init?(fenceHint: String?) {
        guard let hint = fenceHint?.lowercased() else { return nil }
        switch hint {
        case "swift": self = .swift
        case "python", "py": self = .python
        case "java": self = .java
        case "cpp", "c++", "cc", "cxx": self = .cpp
        default: return nil
        }
    }
}
