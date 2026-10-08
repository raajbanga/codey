/// A card's optional main code example (D2, UML 0..1). A value type with no
/// identity of its own: stored as a SwiftData composite attribute locally and
/// as two nullable columns (code_language, code_source) remotely.
struct CodeSnippet: Codable, Hashable {
    var language: CodeLanguage
    var source: String
}
