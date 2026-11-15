import SwiftUI
import UIKit

/// Content card: a rounded note on the dotted paper (`.codeyNote`). An
/// optional tint replaces the hairline with a 1pt colored outline to mark
/// the card that needs attention. Children can use ConcentricRectangle /
/// .containerShape-relative shapes to nest with matching corners.
struct CodeyCard<Content: View>: View {
    var tint: Color?
    @ViewBuilder let content: Content

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(CodeySpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .codeyNote(edge: tint)
            .containerShape(.rect(cornerRadius: CodeyRadius.lg, style: .continuous))
    }
}

extension View {
    /// A rounded note lying on the paper: a raised (or tinted) fill, a
    /// hairline edge, and a barely-there lift. Used by CodeyCard, Home's
    /// topic notes, and the Up-next note.
    func codeyNote(fill: Color = CodeyColor.surfaceRaised, edge: Color? = nil) -> some View {
        background {
            RoundedRectangle.codey(CodeyRadius.lg)
                .fill(fill)
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
        .overlay {
            RoundedRectangle.codey(CodeyRadius.lg)
                .strokeBorder(edge ?? CodeyColor.separator, lineWidth: 1)
        }
    }

    /// A flat raised surface with a hairline outline, for toasts and other
    /// small things floating over content (replaces custom glass, S9).
    func codeyFloatingSurface(in shape: some InsettableShape = RoundedRectangle.codey(CodeyRadius.xl)) -> some View {
        background(CodeyColor.surfaceRaised, in: shape)
            .overlay { shape.strokeBorder(CodeyColor.separator, lineWidth: 1) }
    }

    /// The lifted-note surface (S40) for centered floating cards:
    /// FloatingPanel and CelebrationOverlay. Dotted paper, `xl` corners, a
    /// hairline, and the app's one deep shadow, because the card is off the
    /// page. Small toasts and undo bars keep `codeyFloatingSurface`.
    func codeyFloatingCard() -> some View {
        background { PaperBackground(pattern: .panel) }
            .clipShape(.codey(CodeyRadius.xl))
            .overlay { RoundedRectangle.codey(CodeyRadius.xl).strokeBorder(CodeyColor.separator, lineWidth: 1) }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
    }

    /// The app's page background: warm paper with a faint dot grid. Also
    /// tints the page in brand ink: sheets don't inherit RootView's tint, so
    /// list buttons in them (Sign in with Google) fell back to system blue.
    ///
    /// S41: every scroll view on the paper gets the soft scroll edge effect
    /// on all edges, so content fades and blurs as it passes under the
    /// status bar, a nav bar, or a `codeyBar` (quiz, study) instead of being
    /// cut off. It shows only while something is under the edge.
    func codeyPaperBackground() -> some View {
        background { PaperBackground().ignoresSafeArea() }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .tint(CodeyColor.brand)
    }

    /// A bar pinned to the top or bottom of a page (quiz and study top bar,
    /// Next, summary buttons). Scroll views under it treat it as a bar, so
    /// the soft edge effect sits behind it rather than a hard cut.
    ///
    /// Content is inset by the fade's overshoot (`EdgeFade.overshoot`), so at
    /// rest the first and last rows sit clear of it and only fade once they
    /// scroll under.
    func codeyBar<Bar: View>(_ edge: VerticalEdge, @ViewBuilder _ bar: () -> Bar) -> some View {
        safeAreaBar(edge: edge, spacing: EdgeFade.overshoot) {
            bar()
                .background {
                    // Paper fading out past the bar's inner edge, under the
                    // status bar / home indicator too.
                    EdgeFade(edge: edge)
                        .padding(edge == .top ? .bottom : .top, -EdgeFade.overshoot)
                        .ignoresSafeArea(edges: edge == .top ? .top : .bottom)
                }
        }
    }

    /// Puts a List on the dotted paper. Rows keep the system grouped row
    /// color, which matches SurfaceRaised closely in both modes.
    func codeyListBackground() -> some View {
        scrollContentBackground(.hidden)
            .codeyPaperBackground()
    }
}

/// Warm paper with a dot grid, like a notebook page. The dots stay
/// put while content scrolls over them. Increase Contrast drops the dots so
/// only content carries contrast.
///
/// Floating cards use `.panel`: a finer, staggered grid (S40), so a card
/// lifted off the page reads as a different sheet instead of a cut-out of
/// the page behind it.
struct PaperBackground: View {
    enum Pattern { case page, panel }
    var pattern: Pattern = .page

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        CodeyColor.surface
            .overlay {
                if contrast == .standard {
                    Image(uiImage: pattern == .page ? Self.pageTile : Self.panelTile)
                        .renderingMode(.template)
                        .resizable(resizingMode: .tile)
                        .foregroundStyle(CodeyColor.paperDot)
                        .opacity(pattern == .page ? 1 : 0.8)
                }
            }
            .accessibilityHidden(true)
    }

    /// Page: one 20 pt cell with a 2.4 pt dot (S40: was 1.6, too faint to
    /// read as a notebook page on a phone).
    private static let pageTile = tile(pitch: 20, dot: 2.4, staggered: false)
    /// Panel: 12 pt pitch, 1.5 pt dots, every other row shifted half a cell.
    private static let panelTile = tile(pitch: 12, dot: 1.5, staggered: true)

    /// Drawn once and tiled. A template image, so the dots take PaperDot's
    /// light/dark color at render time.
    private static func tile(pitch: CGFloat, dot: CGFloat, staggered: Bool) -> UIImage {
        let rows: CGFloat = staggered ? 2 : 1
        return UIGraphicsImageRenderer(size: CGSize(width: pitch, height: pitch * rows)).image { _ in
            func dotAt(_ x: CGFloat, _ y: CGFloat) {
                UIBezierPath(ovalIn: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)).fill()
            }
            dotAt(pitch / 2, pitch / 2)
            if staggered {
                dotAt(0, pitch * 1.5)
                dotAt(pitch, pitch * 1.5)
            }
        }
        .withRenderingMode(.alwaysTemplate)
    }
}

/// Paper with a light blur that fades out toward the page (S41): behind
/// every pinned bar and the status bar area, so content scrolling under
/// them softens instead of being cut off or colliding with the bar. Over
/// bare paper it is nearly invisible, so it reads as there only when
/// something passes under it.
struct EdgeFade: View {
    /// How far the fade reaches past a bar or the status bar. Pages inset
    /// their content by the same amount so nothing starts under it.
    static let overshoot = CodeySpacing.lg

    var edge: VerticalEdge = .top

    var body: some View {
        let start: UnitPoint = edge == .top ? .top : .bottom
        let end: UnitPoint = edge == .top ? .bottom : .top
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            CodeyColor.surface.opacity(0.75)
        }
        .mask {
            LinearGradient(
                stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.5), .init(color: .clear, location: 1)],
                startPoint: start, endPoint: end
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// EdgeFade over the status bar area, for pages without a top bar.
struct StatusBarFade: View {
    var body: some View {
        GeometryReader { proxy in
            EdgeFade(edge: .top)
                .frame(height: proxy.safeAreaInsets.top + EdgeFade.overshoot)
                .offset(y: -proxy.safeAreaInsets.top)
        }
        .allowsHitTesting(false)
    }
}
