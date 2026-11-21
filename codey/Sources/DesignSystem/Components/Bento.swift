import SwiftUI

/// Bento layout (S40, S41): every list on Play and Decks is a grid of
/// GameTiles in two columns, under the page's HeroCard (CodeyPage).
///
///     Starter decks                       ← BentoSection title
///     ╭ GameTile ╮ ╭ GameTile ╮
///     ╭ a last odd tile spans both    ╮
///
/// Tiles in a row share its height. At accessibility text sizes the grid
/// becomes one column.

extension View {
    /// Every CodeyPage: paper, no navigation bar, and the soft edge blur at
    /// the top and bottom of the screen.
    func codeyTabPage() -> some View {
        // The nav bar is hidden, so both screen edges get the same soft
        // blur (S41, Nov 15): content blurs out under the clock and under
        // the tab bar / home indicator. The page is inset past each, so
        // nothing is blurred at rest.
        safeAreaPadding(.top, EdgeFade.overshoot(.top))
            .safeAreaPadding(.bottom, EdgeFade.overshoot(.bottom))
            .overlay { ScreenEdgeFade(edge: .top) }
            .overlay { ScreenEdgeFade(edge: .bottom) }
            .codeyPaperBackground()
            .toolbarTitleDisplayMode(.inline)
    }
}

/// A section heading above a grid or note.
struct SectionTitle: View {
    let title: String
    /// How many items the section holds, as a tag after the title.
    var count: Int?
    @Environment(\.codeyLeadsColumn) private var leadsColumn
    /// The count badge's diameter: the title's line height, so it scales with it.
    @ScaledMetric(relativeTo: .headline) private var badge: CGFloat = 22

    init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    var body: some View {
        if leadsColumn {
            // A split page's second column: the title sits above the line
            // the columns share, so the tiles under it start level with
            // the hero. Every titled section puts `sm` under its title.
            label.alignmentGuide(.codeyColumnTop) { $0[.bottom] + CodeySpacing.sm }
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: CodeySpacing.sm) {
            Text(title)
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textSecondary)
            if let count {
                // A circle as tall as the title (a capsule past 2 digits).
                Text("\(count)")
                    .font(.codeyCaption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(CodeyColor.textSecondary)
                    .padding(.horizontal, CodeySpacing.xs)
                    .frame(minWidth: badge, minHeight: badge)
                    .background(CodeyColor.fillNeutral, in: .pill)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(.isHeader)
        .padding(.leading, CodeySpacing.xs)
    }
}

/// An optionally titled BentoGrid.
struct BentoSection<Content: View>: View {
    let title: String?
    var count: Int?
    var columns: BentoColumns = .pair
    @ViewBuilder let content: Content

    init(_ title: String?, count: Int? = nil, columns: BentoColumns = .pair, @ViewBuilder content: () -> Content) {
        self.title = title
        self.count = count
        self.columns = columns
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            if let title { SectionTitle(title, count: count) }
            BentoGrid(columns: columns) { content }
        }
    }
}

/// How many columns a bento grid has.
///
///     .pair    two, always (one at accessibility sizes)
///     .spread  a page's only grid (Decks, Library): two, or three on a
///              page wide enough for two columns (iPad landscape); three
///              wide tiles rather than four skinny ones (Nov 16)
enum BentoColumns: Sendable {
    case pair
    case spread

    func count(pageIsWide: Bool, isAccessibilitySize: Bool) -> Int {
        let base = self == .spread && pageIsWide ? 3 : 2
        return isAccessibilitySize ? max(base - 1, 1) : base
    }
}

/// Equal columns (two by default); in a two-column grid a last odd tile
/// spans the row.
struct BentoGrid<Content: View>: View {
    var columns: BentoColumns = .pair
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.codeyLayout) private var layout
    @Environment(\.codeyPageIsWide) private var pageIsWide

    init(columns: BentoColumns = .pair, @ViewBuilder content: () -> Content) {
        self.columns = columns
        self.content = content()
    }

    var body: some View {
        let columns = columns.count(pageIsWide: pageIsWide, isAccessibilitySize: typeSize.isAccessibilitySize)
        let gap = layout.gridGap
        Group(subviews: content) { tiles in
            Grid(horizontalSpacing: gap, verticalSpacing: gap) {
                ForEach(Array(stride(from: 0, to: tiles.count, by: columns)), id: \.self) { start in
                    GridRow {
                        ForEach(tiles[start..<min(start + columns, tiles.count)]) { tile in
                            let spans = start + 1 == tiles.count && columns == 2
                            tile
                                .frame(maxHeight: .infinity, alignment: .top)
                                .gridCellColumns(spans ? columns : 1)
                        }
                    }
                }
            }
        }
    }
}

struct RowChevron: View {
    var body: some View {
        Icon("chevron.right", size: 16, relativeTo: .callout)
            .foregroundStyle(CodeyColor.textSecondary)
    }
}

/// A titled note with an optional footer (S42, shared Nov 15): Profile's
/// groups and Deck detail's Study section. Lists on the paper are these
/// notes or bento tiles, not grouped List sections.
struct NoteGroup<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let content: Content

    init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            SectionTitle(title)
            VStack(alignment: .leading, spacing: CodeySpacing.sm) { content }
                .codeyCard()
            if let footer {
                Text(footer)
                    .font(.codeyCaption)
                    .foregroundStyle(CodeyColor.textSecondary)
                    .padding(.horizontal, CodeySpacing.xs)
            }
        }
    }
}

