// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        // Default product type is .staticFramework.
        productTypes: [:]
    )
#endif

// Third-party UI dependencies (D1; NFR-15 as amended). Pinned EXACT: Textual is
// pre-1.0, and both are wrapped in single files (CardMarkdownView,
// CodeEditorView) so a swap to the 2.3 fallbacks stays local. See R12.
let package = Package(
    name: "codey",
    dependencies: [
        // Markdown + Prism syntax highlighting for card text. Requires iOS 18+.
        .package(url: "https://github.com/gonzalezreal/textual", exact: "0.5.0"),
        // Code editor for the deck builder. Requires iOS 14+.
        .package(url: "https://github.com/simonbs/Runestone", exact: "0.5.2"),
        // Tree-sitter grammars for Runestone; only the Swift/Python/Java/C++
        // products are linked.
        .package(url: "https://github.com/simonbs/TreeSitterLanguages", exact: "0.1.10"),
    ]
)
