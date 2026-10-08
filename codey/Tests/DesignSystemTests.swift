import SwiftUI
import Testing
import UIKit
@testable import codey

struct TierStyleTests {
    @Test(arguments: [
        (Difficulty.easy, "Easy", "leaf.fill"),
        (.medium, "Medium", "flame.fill"),
        (.hard, "Hard", "bolt.fill"),
    ])
    func mapping(tier: Difficulty, label: String, symbol: String) {
        #expect(tier.style.label == label)
        #expect(tier.style.symbol == symbol)
        #expect(tier.style.accessibilityLabel == "\(label) tier")
    }

    @Test func tiersAreDistinguishableWithoutColor() {
        let styles = Difficulty.allCases.map(\.style)
        #expect(Set(styles.map(\.symbol)).count == styles.count)
        #expect(Set(styles.map(\.label)).count == styles.count)
    }

    @Test func tierColorsComeFromTokens() {
        #expect(Difficulty.easy.style.color == CodeyColor.Tier.easy)
        #expect(Difficulty.medium.style.color == CodeyColor.Tier.medium)
        #expect(Difficulty.hard.style.color == CodeyColor.Tier.hard)
    }
}

struct RadiusTests {
    @Test func scaleIsAscending() {
        let scale = [CodeyRadius.xs, CodeyRadius.sm, CodeyRadius.md, CodeyRadius.lg, CodeyRadius.xl]
        #expect(scale == scale.sorted())
        #expect(scale == [6, 10, 14, 20, 28])
    }

    @Test(arguments: [
        (outer: CGFloat(20), inset: CGFloat(8), expected: CGFloat(12)),
        (outer: 20, inset: 16, expected: 6),   // floors at xs
        (outer: 28, inset: 0, expected: 28),
        (outer: 4, inset: 2, expected: 4),     // never larger than outer
    ])
    func concentric(outer: CGFloat, inset: CGFloat, expected: CGFloat) {
        #expect(CodeyRadius.concentric(outer: outer, inset: inset) == expected)
    }
}

struct ColorTokenTests {
    @Test func everyAssetColorResolves() {
        for name in CodeyColor.assetNames {
            let color = UIColor(named: name, in: .main, compatibleWith: nil)
            #expect(color != nil, "Missing colorset \(name)")
        }
    }

    @Test func assetColorsHaveDistinctDarkVariants() throws {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        for name in CodeyColor.assetNames {
            let color = try #require(UIColor(named: name, in: .main, compatibleWith: nil))
            #expect(color.resolvedColor(with: light) != color.resolvedColor(with: dark), "\(name) has no dark variant")
        }
    }

    @Test func syntaxRolesUseCatalogColors() {
        for role in SyntaxRole.allCases {
            #expect(CodeyColor.assetNames.contains(role.assetName))
        }
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

    @Test func prismCoversTheSameRoles() {
        #expect(SyntaxRole.prismTokens["keyword"] == .keyword)
        #expect(SyntaxRole.prismTokens["class-name"] == .type)
        #expect(SyntaxRole.prismTokens["string"] == .string)
        #expect(SyntaxRole.prismTokens["number"] == .number)
        #expect(SyntaxRole.prismTokens["comment"] == .comment)
        #expect(SyntaxRole.prismTokens["function"] == .function)
        #expect(SyntaxRole.prismTokens["annotation"] == .attribute)
        let used = Set(SyntaxRole.prismTokens.values)
        #expect(used == Set(SyntaxRole.allCases).subtracting([.plain]))
    }
}

struct CardMarkdownCompositionTests {
    @Test(arguments: [(CodeLanguage.swift, "swift"), (.python, "python"), (.java, "java"), (.cpp, "cpp")])
    func prismKeys(language: CodeLanguage, key: String) {
        #expect(language.prismKey == key)
        #expect(CodeLanguage(fenceHint: key) == language)
    }

    @Test func fenceHintAliases() {
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
