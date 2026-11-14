import SwiftUI

/// Bento layout (S40, second pass): every list on Home, Decks and Quiz is
/// a grid of tiles in two columns, so screens share one tile and one grid
/// instead of each building rows.
///
///     Decks                           ← PageHeader (scrolls with the page)
///     Starter decks                   ← BentoSection title
///     ╭ ▣        Starter ╮ ╭ ▣       ╮
///     │ Algorithms       │ │ OS Basics│  ← BentoTile: icon tile, accessory,
///     │ 12 cards         │ │ 12 cards │    title, detail, footer
///     │ ━━━━──      (▶)  │ │ ━━━  (▶) │
///     ╰──────────────────╯ ╰──────────╯
///     ╭ ▣ a last odd tile spans both  ╮
///     ╰───────────────────────────────╯
///
/// Tiles in a row share its height. A spanning tile lays out sideways
/// (icon beside the text) so it isn't a tall empty box. At accessibility
/// text sizes the grid becomes one column.

/// A tab's title inside the scrolling page, as on Home: no large navigation
/// title collapsing into the bar on scroll.
struct PageHeader: View {
    var eyebrow: String?
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.codeyCallout)
                    .foregroundStyle(CodeyColor.textSecondary)
            }
            Text(title)
                .font(.codeyDisplay)
                .foregroundStyle(CodeyColor.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
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
                                .environment(\.bentoWide, spans)
                        }
                    }
                }
            }
        }
    }
}

/// One tile: icon tile and an optional accessory (chip, pin) on top, then
/// title and detail, then an optional footer (progress, buttons) pinned to
/// the bottom. Callers wrap it in a Button or NavigationLink.
struct BentoTile<Accessory: View, Footer: View>: View {
    let icon: String
    let title: String
    var detail: String?
    var minHeight: CGFloat = 132
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var footer: Footer

    @Environment(\.bentoWide) private var wide
    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            if wide {
                HStack(alignment: .top, spacing: CodeySpacing.sm) {
                    IconTile(systemName: icon, size: iconSize, radius: CodeyRadius.sm)
                    text
                    Spacer(minLength: 0)
                    accessory
                }
            } else {
                HStack(alignment: .top, spacing: CodeySpacing.xs) {
                    IconTile(systemName: icon, size: iconSize, radius: CodeyRadius.sm)
                    Spacer(minLength: 0)
                    accessory
                }
                text
                Spacer(minLength: 0)
            }
            footer
        }
        .padding(CodeySpacing.md)
        .frame(maxWidth: .infinity, minHeight: wide ? 0 : minHeight, maxHeight: .infinity, alignment: .topLeading)
        .codeyNote()
        .contentShape(.rect(cornerRadius: CodeyRadius.lg))
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
            Text(title)
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textPrimary)
            if let detail {
                Text(detail)
                    .font(.codeySubheadline)
                    .monospacedDigit()
                    .foregroundStyle(CodeyColor.textSecondary)
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension EnvironmentValues {
    /// Set by BentoGrid on a tile that spans the row.
    @Entry var bentoWide = false
}

extension BentoTile where Accessory == EmptyView {
    init(icon: String, title: String, detail: String? = nil, minHeight: CGFloat = 132, @ViewBuilder footer: () -> Footer) {
        self.init(icon: icon, title: title, detail: detail, minHeight: minHeight, accessory: { EmptyView() }, footer: footer)
    }
}

extension BentoTile where Accessory == EmptyView, Footer == EmptyView {
    init(icon: String, title: String, detail: String? = nil, minHeight: CGFloat = 132) {
        self.init(icon: icon, title: title, detail: detail, minHeight: minHeight, accessory: { EmptyView() }, footer: { EmptyView() })
    }
}

struct RowChevron: View {
    var body: some View {
        Icon("chevron.right", size: 16, relativeTo: .callout)
            .foregroundStyle(CodeyColor.textSecondary)
    }
}
