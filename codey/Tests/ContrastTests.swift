import Testing
import UIKit
@testable import codey

/// NFR-12: WCAG 4.5:1 for every text/background pair, checked against the
/// SHIPPED asset-catalog colors in light and dark (the same pairs
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

        func contrast(with other: RGB) -> CGFloat {
            let (hi, lo) = (max(luminance, other.luminance), min(luminance, other.luminance))
            return (hi + 0.05) / (lo + 0.05)
        }
    }

    private static func asset(_ name: String) -> UIColor {
        UIColor(named: name, in: .main, compatibleWith: nil)!
    }

    private static let styles: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]

    /// Text colors on both surfaces and, where one exists, on their own
    /// pastel fill (Success → SuccessSoft, TierEasy → TierEasySoft).
    @Test(arguments: [
        ("TextPrimary", nil), ("TextSecondary", nil), ("Brand", "BrandSoft"),
        ("Success", "SuccessSoft"), ("Warning", "WarningSoft"), ("Danger", "DangerSoft"),
        ("TierEasy", "TierEasySoft"), ("TierMedium", "TierMediumSoft"), ("TierHard", "TierHardSoft"),
    ] as [(String, String?)])
    func textColorPassesOnSurfaces(name: String, soft: String?) {
        for (style, label) in Self.styles {
            let text = RGB(Self.asset(name), style)
            let backgrounds = ["Surface", "SurfaceRaised"] + (soft.map { [$0] } ?? [])
            for background in backgrounds {
                let ratio = text.contrast(with: RGB(Self.asset(background), style))
                #expect(ratio >= 4.5, "\(name) on \(background) (\(label)): \(ratio)")
            }
        }
    }

    @Test func inkLabelsPassOnBrandFill() {
        for (style, label) in Self.styles {
            let ratio = RGB(Self.asset("OnBrandFill"), style).contrast(with: RGB(Self.asset("BrandFill"), style))
            #expect(ratio >= 4.5, "OnBrandFill on BrandFill (\(label)): \(ratio)")
        }
    }

    @Test(arguments: SyntaxRole.allCases.map(\.assetName))
    func syntaxColorPassesOnCodeBackground(name: String) {
        for (style, label) in Self.styles {
            let ratio = RGB(Self.asset(name), style).contrast(with: RGB(Self.asset("CodeBackground"), style))
            #expect(ratio >= 4.5, "\(name) on code (\(label)): \(ratio)")
        }
    }
}
