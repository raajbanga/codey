import SwiftUI
import Testing
import UIKit
@testable import codey

/// NFR-12: tiers never rely on color alone.
struct TierStyleTests {
    @Test func tiersAreDistinguishableWithoutColor() {
        let styles = Difficulty.allCases.map(\.style)
        #expect(Set(styles.map(\.symbol)).count == styles.count)
        #expect(Set(styles.map(\.label)).count == styles.count)
    }
}

struct ColorTokenTests {
    /// Every asset-catalog color the tokens use.
    static let assetNames = ["Brand", "BrandFill", "BrandSoft", "Success", "Warning", "Danger",
                             "TierEasy", "TierMedium", "TierHard", "CodeBackground"]
        + SyntaxRole.allCases.map(\.assetName)

    @Test func everyAssetColorResolves() {
        for name in Self.assetNames {
            let color = UIColor(named: name, in: .main, compatibleWith: nil)
            #expect(color != nil, "Missing colorset \(name)")
        }
    }

    @Test func assetColorsHaveDistinctDarkVariants() throws {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        for name in Self.assetNames {
            let color = try #require(UIColor(named: name, in: .main, compatibleWith: nil))
            #expect(color.resolvedColor(with: light) != color.resolvedColor(with: dark), "\(name) has no dark variant")
        }
    }

    @Test func syntaxAssetNames() {
        #expect(SyntaxRole.keyword.assetName == "SyntaxKeyword")
        #expect(SyntaxRole.plain.assetName == "SyntaxPlain")
    }
}

struct SyntaxRoleTests {
    /// Every capture used by the bundled Swift/Python/Java/C++ highlight
    /// queries that should be colored.
    @Test(arguments: [
        ("keyword", SyntaxRole.keyword), ("keyword.return", .keyword), ("keyword.function", .keyword),
        ("conditional", .keyword), ("repeat", .keyword), ("include", .keyword), ("boolean", .keyword),
        ("constant.builtin", .keyword),
        ("type", .type), ("type.builtin", .type), ("constructor", .type),
        ("string", .string), ("string.regex", .string), ("escape", .string),
        ("number", .number), ("float", .number), ("constant", .number),
        ("comment", .comment),
        ("function", .function), ("function.method", .function), ("function.call", .function),
        ("function.macro", .function), ("method", .function),
        ("attribute", .attribute), ("label", .attribute),
    ])
    func treeSitterCaptures(capture: String, role: SyntaxRole) {
        #expect(SyntaxRole(treeSitterCapture: capture) == role)
    }

    @Test(arguments: ["operator", "variable", "variable.builtin", "parameter", "property", "punctuation.bracket", "spell"])
    func uncoloredCapturesRenderPlain(capture: String) {
        #expect(SyntaxRole(treeSitterCapture: capture) == nil)
    }

    @Test func prismCoversEveryColoredRole() {
        let used = Set(SyntaxRole.prismTokens.values)
        #expect(used == Set(SyntaxRole.allCases).subtracting([.plain]))
    }
}

struct CardMarkdownCompositionTests {
    @Test func fenceHintsRoundTripAndAcceptAliases() {
        for language in CodeLanguage.allCases {
            #expect(CodeLanguage(fenceHint: language.rawValue) == language)
        }
        #expect(CodeLanguage(fenceHint: "C++") == .cpp)
        #expect(CodeLanguage(fenceHint: "py") == .python)
        #expect(CodeLanguage(fenceHint: "rust") == nil)
        #expect(CodeLanguage(fenceHint: nil) == nil)
    }

    @Test func noSnippetLeavesMarkdownUntouched() {
        #expect(CardMarkdownComposition.compose(markdown: "  **Hi**\n", snippet: nil) == "  **Hi**\n")
    }

    @Test func snippetIsAppendedAsFencedBlock() {
        let result = CardMarkdownComposition.compose(
            markdown: "What prints?\n",
            snippet: CodeSnippet(language: .cpp, source: "std::cout << 1;")
        )
        #expect(result == "What prints?\n\n```cpp\nstd::cout << 1;\n```")
    }

    @Test func snippetAloneHasNoLeadingBlankLines() {
        let result = CardMarkdownComposition.compose(markdown: "  ", snippet: CodeSnippet(language: .swift, source: "let x = 1"))
        #expect(result == "```swift\nlet x = 1\n```")
    }

    @Test func backticksInsideSourceGetALongerFence() {
        let source = "let md = \"\"\"\n```swift\ncode\n```\n\"\"\""
        let result = CardMarkdownComposition.compose(markdown: "Q", snippet: CodeSnippet(language: .swift, source: source))
        #expect(result == "Q\n\n````swift\n\(source)\n````")
        #expect(CardMarkdownComposition.fence(for: "a ````` b") == "``````")
        #expect(CardMarkdownComposition.fence(for: "`x`") == "```")
    }
}

struct MarkdownFormattingTests {
    private func apply(_ format: MarkdownFormat, _ text: String, _ range: Range<Int>) -> MarkdownFormatting.Result {
        MarkdownFormatting.apply(format, to: text, selection: range)
    }

    @Test func boldWrapsSelection() {
        let result = apply(.bold, "make this bold", 10..<14)
        #expect(result.text == "make this **bold**")
        #expect(result.selection == 12..<16)
    }

    @Test func emptySelectionInsertsPairWithCursorInside() {
        let result = apply(.code, "use ", 4..<4)
        #expect(result.text == "use ``")
        #expect(result.selection == 5..<5)
    }

    @Test func applyingTwiceRemovesMarkers() {
        let once = apply(.italic, "word", 0..<4)
        #expect(once.text == "_word_")
        let twice = apply(.italic, once.text, once.selection)
        #expect(twice.text == "word")
        #expect(twice.selection == 0..<4)
    }

    @Test func outOfRangeSelectionIsClamped() {
        #expect(apply(.bold, "ab", 5..<9).text == "ab****")
    }

    @Test func bulletsCoverEveryTouchedLine() {
        let result = apply(.bulletList, "intro\nfirst\nsecond", 8..<14)
        #expect(result.text == "intro\n- first\n- second")
        #expect(result.selection == 6..<22)
    }

    @Test func bulletsToggleOffWhenAllLinesHaveThem() {
        let result = apply(.bulletList, "- a\n- b", 0..<7)
        #expect(result.text == "a\nb")
    }

    @Test func unicodeOffsetsAreCharacters() {
        let result = apply(.bold, "👍🏽 ok", 0..<1)
        #expect(result.text == "**👍🏽** ok")
    }
}
