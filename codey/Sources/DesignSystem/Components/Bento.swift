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

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.codeyHeadline)
            .foregroundStyle(CodeyColor.textSecondary)
            .accessibilityAddTraits(.isHeader)
            .padding(.leading, CodeySpacing.xs)
    }
}

/// An optionally titled BentoGrid.
struct BentoSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            if let title { SectionTitle(title) }
            BentoGrid { content }
        }
    }
}

/// Two equal columns; a last odd tile spans the row.
struct BentoGrid<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var typeSize
    private let gap = CodeySpacing.sm + CodeySpacing.xs

    var body: some View {
        let columns = typeSize.isAccessibilitySize ? 1 : 2
        Group(subviews: content) { tiles in
            Grid(horizontalSpacing: gap, verticalSpacing: gap) {
                ForEach(Array(stride(from: 0, to: tiles.count, by: columns)), id: \.self) { start in
                    GridRow {
                        ForEach(tiles[start..<min(start + columns, tiles.count)]) { tile in
                            let spans = start + 1 == tiles.count && columns > 1
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

