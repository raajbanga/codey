import Testing
import UIKit
@testable import codey

/// NFR-12: WCAG 4.5:1 for every text/background pair, checked against the
/// SHIPPED asset-catalog and system colors in light and dark (the same pairs
/// as scripts/palette/palette.py, which only checks its own hex table).
struct ContrastTests {
    private struct RGB {
        let r, g, b: CGFloat

        init(_ color: UIColor, _ style: UIUserInterfaceStyle) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style)).getRed(&r, green: &g, blue: &b, alpha: &a)
            self.r = r; self.g = g; self.b = b
        }

        init(r: CGFloat, g: CGFloat, b: CGFloat) {
            self.r = r; self.g = g; self.b = b
        }

        var luminance: CGFloat {
            func channel(_ c: CGFloat) -> CGFloat {
                let c = min(max(c, 0), 1)
                return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
        }

        func blended(over background: RGB, opacity: CGFloat) -> RGB {
            RGB(r: r * opacity + background.r * (1 - opacity),
                g: g * opacity + background.g * (1 - opacity),
                b: b * opacity + background.b * (1 - opacity))
        }

        func contrast(with other: RGB) -> CGFloat {
            let (hi, lo) = (max(luminance, other.luminance), min(luminance, other.luminance))
            return (hi + 0.05) / (lo + 0.05)
        }
    }

    private static func asset(_ name: String) -> UIColor {
        UIColor(named: name, in: .main, compatibleWith: nil)!
    }

    private static let styles: [(UIUserInterfaceStyle, String, softOpacity: CGFloat)] = [
        (.light, "light", 0.12), (.dark, "dark", 0.16),
    ]

    /// Text colors used on the grouped surfaces and on their own soft fill.
    @Test(arguments: ["Brand", "Success", "Warning", "Danger", "TierEasy", "TierMedium", "TierHard"])
    func textColorPassesOnSurfaces(name: String) {
        for (style, label, softOpacity) in Self.styles {
            let text = RGB(Self.asset(name), style)
            let raised = RGB(.secondarySystemGroupedBackground, style)
            let grouped = RGB(.systemGroupedBackground, style)
            for (background, where_) in [(raised, "raised"), (grouped, "grouped"),
                                         (text.blended(over: raised, opacity: softOpacity), "own soft fill")] {
                let ratio = text.contrast(with: background)
                #expect(ratio >= 4.5, "\(name) on \(where_) (\(label)): \(ratio)")
            }
        }
    }

    @Test func whiteLabelsPassOnBrandFill() {
        for (style, label, _) in Self.styles {
            let ratio = RGB(.white, style).contrast(with: RGB(Self.asset("BrandFill"), style))
            #expect(ratio >= 4.5, "white on BrandFill (\(label)): \(ratio)")
        }
    }

    @Test(arguments: SyntaxRole.allCases.map(\.assetName) + ["SyntaxPlain"])
    func syntaxColorPassesOnCodeBackground(name: String) {
        for (style, label, _) in Self.styles {
            let ratio = RGB(Self.asset(name), style).contrast(with: RGB(Self.asset("CodeBackground"), style))
            #expect(ratio >= 4.5, "\(name) on code (\(label)): \(ratio)")
        }
    }
}
