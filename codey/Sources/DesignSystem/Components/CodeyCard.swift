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
        content.codeyCard(tint: tint)
    }
}

extension View {
    /// CodeyCard as a modifier, for a view that is already a stack.
    func codeyCard(tint: Color? = nil) -> some View {
        padding(CodeySpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .codeyNote(edge: tint)
            .containerShape(.rect(cornerRadius: CodeyRadius.lg, style: .continuous))
    }

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
    /// small things floating over content (toasts, undo bars).
    func codeyFloatingSurface(in shape: some InsettableShape = RoundedRectangle.codey(CodeyRadius.xl)) -> some View {
        background(CodeyColor.surfaceRaised, in: shape)
            .overlay { shape.strokeBorder(CodeyColor.separator, lineWidth: 1) }
    }

    /// The inside of every floating card (quiz setup, Ask Codey, dialogs,
    /// celebrations; Nov 15): page-margin sides, roomier top and bottom,
    /// so their content lines up with each other and with the page.
    func codeyPanelPadding() -> some View {
        padding(.horizontal, CodeySpacing.md)
            .padding(.vertical, CodeySpacing.lg)
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
    /// Content passing under the status bar or a `codeyBar` fades into
    /// our own EdgeFade; the system's scroll edge effect is off so the
    /// look is the same on every platform (Nov 15).
    func codeyPaperBackground() -> some View {
        background { PaperBackground().ignoresSafeArea() }
            .scrollEdgeEffectHidden(true, for: .all)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .tint(CodeyColor.brand)
    }

    /// A bar pinned to the top or bottom of a page (quiz and study top bar,
    /// Next, summary buttons). Scroll views under it treat it as a bar, so
    /// the soft edge effect sits behind it rather than a hard cut.
    ///
    /// Content is inset by the fade's overshoot (`EdgeFade.overshoot(_:)`), so at
    /// rest the first and last rows sit clear of it and only fade once they
    /// scroll under.
    func codeyBar<Bar: View>(_ edge: VerticalEdge, @ViewBuilder _ bar: () -> Bar) -> some View {
        safeAreaBar(edge: edge, spacing: EdgeFade.overshoot(edge)) {
            bar()
                .background {
                    // Paper fading out past the bar's inner edge, under the
                    // status bar / home indicator too.
                    EdgeFade(edge: edge)
                        .padding(edge == .top ? .bottom : .top, -EdgeFade.feather(edge))
                        .ignoresSafeArea(edges: edge == .top ? .top : .bottom)
                }
        }
    }
}

/// A 1 pt line in the separator color (menu rows, a card's prompt and
/// answer): ours, not the system Divider, so it ports as is.
struct HairlineDivider: View {
    var body: some View {
        Rectangle().fill(CodeyColor.separator).frame(height: 1).accessibilityHidden(true)
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

/// The soft edge where content scrolls under the top or bottom of the
/// screen (S41; Nov 15: pure blur, feathered, shorter at the top). A
/// backdrop blur with no tint layer, strongest at the screen edge and
/// eased to clear over the bar or inset plus `feather`, so there is no
/// visible line or darker band. It is our own element: on Android it is
/// the same thing (a RenderEffect backdrop blur, e.g. Haze, under the same
/// gradient mask). The tab bar is the one system-drawn piece.
struct EdgeFade: View {
    /// How far the blur reaches past a bar or the screen edge: short at
    /// the top, where the status bar is already clear space, longer at the
    /// bottom over the tab bar and home indicator (Nov 15).
    static func feather(_ edge: VerticalEdge) -> CGFloat {
        edge == .top ? CodeySpacing.sm + CodeySpacing.xs : CodeySpacing.xxl + CodeySpacing.md
    }
    /// How far pages inset their content past the edge, so at rest the
    /// first and last rows sit clear of the blur. Just past the top
    /// feather, so pages start high (Nov 15).
    static func overshoot(_ edge: VerticalEdge) -> CGFloat {
        edge == .top ? CodeySpacing.md : CodeySpacing.xl
    }

    var edge: VerticalEdge = .top

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask {
                LinearGradient(
                    stops: Self.stops,
                    startPoint: edge == .top ? .top : .bottom,
                    endPoint: edge == .top ? .bottom : .top
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// One smoothstep from the screen edge to clear over the whole height
    /// (no steady part, so no visible step anywhere, Nov 15).
    private static let stops: [Gradient.Stop] = (0...16).map { i in
        let t = CGFloat(i) / 16
        let eased = t * t * (3 - 2 * t)
        return .init(color: .black.opacity(strength * (1 - eased)), location: t)
    }

    /// Peak strength, at the very edge: enough to soften what passes
    /// under, not so much that the material's frost reads as a haze.
    private static let strength = 0.7
}

/// EdgeFade over the screen's top or bottom inset (status bar, home
/// indicator, tab bar), for pages without a bar of their own there.
struct ScreenEdgeFade: View {
    let edge: VerticalEdge

    var body: some View {
        GeometryReader { proxy in
            let inset = edge == .top ? proxy.safeAreaInsets.top : proxy.safeAreaInsets.bottom
            EdgeFade(edge: edge)
                .frame(height: inset + EdgeFade.feather(edge))
                .offset(y: edge == .top ? -inset : proxy.size.height - EdgeFade.feather(edge))
        }
        .allowsHitTesting(false)
    }
}
