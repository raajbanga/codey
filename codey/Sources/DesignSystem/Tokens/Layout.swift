import SwiftUI

/// The app's width class (iPad, Nov 16): read once, from the window's
/// horizontal size class, in `RootView`, and passed down as `codeyLayout`.
/// Nothing else reads the size class or the device: split view, Slide Over
/// and narrow Stage Manager windows are compact, so they get the iPhone
/// layout. Only the shared components use it (CodeyPage, BentoGrid,
/// GameTile, HeroCard, FloatingPanel, SessionSummary); a screen gets the
/// iPad layout by using them.
///
///                      compact (iPhone)   regular (iPad)
///     page margin            16                32
///     grid gap               12                18
///     text floor            —           xxxLarge  (body 17 → 23 pt)
///     tile / hero / card     16                28    (padding)
///     tile min height       150               240
///     floating card inset    24                32    (panels, dialogs)
///     dialog width          360               520
///     readable width         —                788   (sessions, panels)
///     flashcard        full × 260+       640 × 480+
///
/// Regular width leans chunky (Nov 16): fewer, wider tiles with more
/// room inside, not more, skinnier ones, and bigger text, so the extra
/// space goes to the pastel cards themselves (the flashcard feel), not to
/// gaps around them.
enum CodeyLayout: Sendable {
    case compact
    case regular

    init(_ sizeClass: UserInterfaceSizeClass?) {
        self = sizeClass == .regular ? .regular : .compact
    }

    var isRegular: Bool { self == .regular }

    /// A page's side and bottom margin (CodeyPage).
    var pageMargin: CGFloat { isRegular ? CodeySpacing.xl : CodeySpacing.md }

    /// Between bento tiles, both ways, and between a split page's columns.
    var gridGap: CGFloat { isRegular ? CodeySpacing.md + CodeySpacing.xxs : CodeySpacing.sm + CodeySpacing.xs }

    /// Inside a GameTile, a HeroCard and a CodeyCard.
    var cardPadding: CGFloat { isRegular ? CodeySpacing.lg + CodeySpacing.xs : CodeySpacing.md }

    /// A GameTile's shortest height.
    var tileMinHeight: CGFloat { isRegular ? 240 : 150 }

    /// Inside every floating card (panels, dialogs, celebrations).
    var panelPadding: CGFloat { isRegular ? CodeySpacing.xl : CodeySpacing.lg }

    /// The widest a confirmation dialog gets.
    var dialogWidth: CGFloat { isRegular ? 520 : 360 }

    /// A celebration's symbol: its size and the circle around it.
    var celebrationSymbol: (size: CGFloat, circle: CGFloat) { isRegular ? (48, 96) : (32, 64) }

    /// The widest a session (study, quiz, exercise, summaries) or a
    /// floating panel gets: lines of text and the code editor stay a
    /// readable length on a 13-inch screen. nil: the full width. Sessions
    /// pad 16 inside it, so their content is 756 wide: the same as a page's
    /// in iPad (A16) portrait (820 less two 32 pt margins), and a session
    /// lines up with the page under it.
    var readableWidth: CGFloat? { isRegular ? 788 : nil }

    /// A study flashcard: an index card on iPad (narrower, taller), the
    /// screen's width on iPhone.
    var flashcard: (maxWidth: CGFloat?, minHeight: CGFloat) { isRegular ? (640, 480) : (nil, 260) }

    /// A page at least this wide shows its `trailing` section as a second
    /// column (two phone-width columns in iPad landscape). Measured on the
    /// page itself, not the orientation, so Stage Manager windows follow.
    static let splitWidth: CGFloat = 1000

    /// iPadOS draws the tab bar floating at the top of a tab root, which
    /// pushes the page down by its height. A tab root on regular width
    /// lifts its button row onto the tab bar's line instead, so the bar
    /// sits between the leading badge and the round buttons: this is how
    /// far past the status bar that row starts (centring 44 pt buttons on
    /// the bar).
    static let tabBarRowInset: CGFloat = CodeySpacing.xs

    /// The text-size floor on regular width: body 17 → 23 pt, the largest
    /// size below the accessibility sizes. A floor, so a larger setting
    /// still wins; not an accessibility size, so the bento grid keeps its
    /// columns unless the reader asked for bigger text.
    static let regularTypeFloor = DynamicTypeSize.xxxLarge
}

extension EnvironmentValues {
    @Entry var codeyLayout = CodeyLayout.compact
    /// The window's top safe area: the status bar alone, measured at the
    /// root, outside the tab view (whose top bar adds its own inset).
    @Entry var codeyStatusBarInset: CGFloat = 0
    /// The window's size, measured at the root (Mac sheets fit inside it).
    @Entry var codeyWindowSize = CGSize.zero
    /// Set by CodeyPage on the first item of a split page's second column:
    /// its section title sits above the column line (`codeyColumnTop`).
    @Entry var codeyLeadsColumn = false
    /// Set by CodeyPage on its content: the page is wide enough for two
    /// columns (`CodeyLayout.splitWidth`). Spread bento grids double up.
    @Entry var codeyPageIsWide = false
}

extension View {
    /// Sets `codeyLayout` from the size class and the regular-width text
    /// floor. Once, at the app root; sheets and covers inherit both.
    func codeyLayoutRoot(_ sizeClass: UserInterfaceSizeClass?) -> some View {
        modifier(LayoutRoot(layout: CodeyLayout(sizeClass)))
    }

    /// A tab root's button row on the tab bar's line (iPad): drops the tab
    /// bar's top inset and keeps only the status bar's, so the page (and
    /// its top fade) start where the bar does. No change when `isOn` is off.
    func codeyBesideTabBar(_ isOn: Bool) -> some View {
        modifier(BesideTabBar(isOn: isOn))
    }

    /// A large sheet (Profile): the page sheet on iPad, not the small form
    /// sheet. Mac Catalyst sizes a page sheet from the screen, not the
    /// window, so its bottom ran off a short window (Nov 16); there it's
    /// fitted to an ideal size, which the window clamps.
    func codeyPageSheet() -> some View {
        modifier(PageSheet())
    }

    /// Caps the width at `CodeyLayout.readableWidth`, centred; no change
    /// on compact width (or when `isOn` is false).
    func codeyReadableWidth(_ isOn: Bool = true) -> some View {
        modifier(ReadableWidth(isOn: isOn))
    }
}

private struct LayoutRoot: ViewModifier {
    let layout: CodeyLayout
    @State private var statusBarInset: CGFloat = 0
    @State private var windowSize = CGSize.zero

    func body(content: Content) -> some View {
        content
            .environment(\.codeyLayout, layout)
            .environment(\.codeyStatusBarInset, statusBarInset)
            .environment(\.codeyWindowSize, windowSize)
            .modifier(TypeFloor(isOn: layout.isRegular))
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { statusBarInset = $0 }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { windowSize = $0 }
    }
}

private struct BesideTabBar: ViewModifier {
    let isOn: Bool
    @Environment(\.codeyStatusBarInset) private var statusBarInset

    func body(content: Content) -> some View {
        content
            // Less the page's own top inset (EdgeFade.overshoot), which
            // codeyTabPage adds inside this.
            .safeAreaPadding(.top, isOn ? statusBarInset + CodeyLayout.tabBarRowInset - EdgeFade.overshoot(.top) : 0)
            .ignoresSafeArea(.container, edges: isOn ? .top : [])
    }
}

private struct PageSheet: ViewModifier {
    @Environment(\.codeyWindowSize) private var window

    func body(content: Content) -> some View {
        #if targetEnvironment(macCatalyst)
        // The iPad page sheet's size, less a margin all round, so the
        // window's dimmed edge shows past it.
        content
            .frame(
                width: max(min(window.width - 2 * Self.margin, 820), 320),
                height: max(window.height - 2 * Self.margin, 320)
            )
            .presentationSizing(.fitted)
        #else
        content.presentationSizing(.page)
        #endif
    }

    private static let margin = CodeySpacing.xxl
}

private struct TypeFloor: ViewModifier {
    let isOn: Bool

    /// One branch, so moving between full screen and split view keeps the
    /// app's view identity (and state); compact clamps to the full range.
    func body(content: Content) -> some View {
        content.dynamicTypeSize((isOn ? CodeyLayout.regularTypeFloor : .xSmall)...)
    }
}

private struct ReadableWidth: ViewModifier {
    let isOn: Bool
    @Environment(\.codeyLayout) private var layout

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: isOn ? layout.readableWidth : nil)
            .frame(maxWidth: .infinity)
    }
}

extension VerticalAlignment {
    private enum ColumnTop: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context[.top] }
    }

    /// Where a split page's two columns line up: the hero's top on the
    /// left, and on the right the first tile under the column's first
    /// section title (which sits above the line, beside the button row).
    static let codeyColumnTop = VerticalAlignment(ColumnTop.self)
}
