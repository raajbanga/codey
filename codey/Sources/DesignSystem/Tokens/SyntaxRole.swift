import SwiftUI

/// The small set of code colors Codey uses. Both highlighters map onto it:
/// Prism token types (Textual, display) and tree-sitter captures
/// (Runestone, editor). So a keyword is the same color in the builder and in
/// study.
enum SyntaxRole: String, CaseIterable {
    case plain, keyword, type, string, number, comment, function, attribute

    /// Asset-catalog name ("SyntaxKeyword"), also used by UIKit (Runestone).
    var assetName: String { "Syntax" + rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    var color: Color { Color(assetName) }

    /// Prism token type → role. Unknown tokens render plain.
    static let prismTokens: [String: SyntaxRole] = [
        "keyword": .keyword, "boolean": .keyword, "literal": .keyword, "nil": .keyword,
        "important": .keyword,
        "class-name": .type, "builtin": .type, "namespace": .type,
        "string": .string, "char": .string, "regex": .string, "url": .string,
        "number": .number, "constant": .number,
        "comment": .comment, "block-comment": .comment, "doc-comment": .comment,
        "function": .function, "function-name": .function, "function-definition": .function,
        "attribute": .attribute, "annotation": .attribute, "directive": .attribute,
        "preprocessor": .attribute, "macro": .attribute, "other-directive": .attribute,
    ]

    /// Tree-sitter capture (e.g. "keyword.return", "function.method") →
    /// role, by its first component. Unknown captures render plain.
    init?(treeSitterCapture name: String) {
        let head = name.split(separator: ".", maxSplits: 1).first.map(String.init) ?? name
        switch head {
        case "keyword", "conditional", "repeat", "include", "exception", "boolean":
            self = .keyword
        case "constant" where name == "constant.builtin":
            self = .keyword
        case "type", "constructor":
            self = .type
        case "string", "escape", "character":
            self = .string
        case "number", "float", "constant":
            self = .number
        case "comment":
            self = .comment
        case "function", "method":
            self = .function
        case "attribute", "label", "preproc":
            self = .attribute
        default:
            return nil
        }
    }
}
