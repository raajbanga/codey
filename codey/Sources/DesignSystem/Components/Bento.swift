import SwiftUI

/// Bento layout (S40, S41): every list on Play and Decks is a grid of
/// GameTiles in two columns, under a TabHeader.
///
///     Decks                     (⌕) (+)   ← TabHeader: title, round buttons
///     Starter decks                       ← BentoSection title
///     ╭ GameTile ╮ ╭ GameTile ╮
///     ╭ a last odd tile spans both    ╮
///
/// Tiles in a row share its height. At accessibility text sizes the grid
/// becomes one column.

/// A tab's title at the top of its scrolling page (Play, Decks): an
/// optional line above, the title, and round buttons on the right. No large
/// navigation title collapsing into the bar.
struct TabHeader<Trailing: View>: View {
    var eyebrow: String?
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: CodeySpacing.sm) {
            VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                }
                Text(title)
                    .font(.codeyTitle.weight(.semibold))
                    .foregroundStyle(CodeyColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing
        }
    }
}

extension View {
    /// A tab's root page (Home, Decks, Quiz): paper and no large title (the
    /// PageHeader scrolls with the page).
    func codeyTabPage() -> some View {
        // The nav bar is hidden, so the status bar area gets the same edge
        // fade as a bar (S41): content fades out instead of running into
        // the clock.
        // The page starts below the fade, so the header is clear at rest.
        safeAreaPadding(.top, EdgeFade.overshoot)
            .overlay(alignment: .top) { StatusBarFade() }
            .codeyPaperBackground()
            .toolbarTitleDisplayMode(.inline)
    }
}

/// A pushed page's or sheet's title (S40): shown in the bar at the top of
/// the page and faded out once the page scrolls, so only the bar's buttons
/// stay over the content. `navigationTitle` still names the page for the
/// back-button menu and VoiceOver.
private struct FadingTitle: ViewModifier {
    let title: String
    @State private var scrolled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.codeyHeadline)
                        .foregroundStyle(CodeyColor.textPrimary)
                        .lineLimit(1)
                        .opacity(scrolled ? 0 : 1)
                        .animation(CodeyMotion.resolve(CodeyMotion.pop, reduceMotion: reduceMotion), value: scrolled)
                        .accessibilityHidden(scrolled)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > CodeySpacing.sm
            } action: { _, isScrolled in
                scrolled = isScrolled
            }
    }
}

extension View {
    func codeyPageTitle(_ title: String) -> some View {
        modifier(FadingTitle(title: title))
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
