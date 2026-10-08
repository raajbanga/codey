// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        // Default product type is .staticFramework.
        productTypes: [:]
    )
#endif

// Third-party dependencies (D1; NFR-15 as amended), all pinned EXACT. Textual is
// pre-1.0; Textual and Runestone are wrapped in single files (CardMarkdownView,
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
        // Backend (Stage 9): auth + PostgREST sync. Only imported under
        // Services/Backend/Supabase/ (scripts/check-imports.sh).
        .package(url: "https://github.com/supabase/supabase-swift", exact: "2.55.3"),
        // Google sign-in. 10.0.0 is the first release that supports Xcode 27.
        .package(url: "https://github.com/google/GoogleSignIn-iOS", exact: "10.0.0"),
        // Transitive pins for supabase-swift. xctest-dynamic-overlay 1.13 became
        // a shim over swift-issue-reporting with a same-named product, which
        // Tuist resolves into a self-cycle ("circular dependency
        // _IssueReporting"). These are the last versions without the shim.
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", exact: "1.11.0"),
        .package(url: "https://github.com/pointfreeco/swift-clocks", exact: "1.0.6"),
    ]
)
