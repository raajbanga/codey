import SwiftUI

/// Every page that isn't a session (§3b, Nov 15): a row of round buttons,
/// the page's hero card, then the content, all scrolling on paper. There
/// is no navigation bar and no back button: pushed pages go back with the
/// edge swipe (and VoiceOver's escape gesture). A sheet passes `closes`,
/// which puts a round ✕ at the leading end.
///
///     🔥4                      (▲) (◎)    ← buttons only
///     ╭ (icon) subtitle     [badge] ╮
///     │ Title                       │     ← HeroCard, in the page's pastel
///     │ ━━━━━━━━━━━━──────          │
///     ╰ caption                     ╯
///     …content…
struct CodeyPage<Actions: View, Leading: View, Hero: View, Content: View>: View {
    let title: String
    var closes = false
    var closeID = "page.close"
    /// Play and Decks: the only pages that show the tab bar.
    var isTabRoot = false
    @ViewBuilder var actions: Actions
    @ViewBuilder var leading: Leading
    @ViewBuilder var hero: Hero
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    init(
        _ title: String,
        closes: Bool = false,
        closeID: String = "page.close",
        isTabRoot: Bool = false,
        @ViewBuilder actions: () -> Actions = { EmptyView() },
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.closes = closes
        self.closeID = closeID
        self.isTabRoot = isTabRoot
        self.actions = actions()
        self.leading = leading()
        self.hero = hero()
        self.content = content()
    }

    private var hasButtons: Bool {
        closes || Actions.self != EmptyView.self || Leading.self != EmptyView.self
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                    if hasButtons {
                        HStack(spacing: CodeySpacing.sm) {
                            if closes {
                                CircleIconButton(systemImage: "xmark", label: "Close") { dismiss() }
                                    .accessibilityIdentifier(closeID)
                            }
                            leading
                            Spacer(minLength: 0)
                            actions
                        }
                        .frame(minHeight: 44)
                    }
                    hero
                }
                content
            }
            .padding([.horizontal, .bottom], CodeySpacing.md)
            // A sheet has no status bar above it: clear its rounded top.
            .padding(.top, closes ? CodeySpacing.md : 0)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .codeyTabPage()
        // A page under a tab root is a focused task: the tab bar steps
        // aside (it's back as soon as you swipe back).
        .toolbarVisibility(isTabRoot ? .automatic : .hidden, for: .tabBar)
        // Names the page for VoiceOver and the long-press back list.
        .navigationTitle(title)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .background { SwipeBackEnabler().frame(width: 0, height: 0).accessibilityHidden(true) }
        .accessibilityAction(.escape) { dismiss() }
    }
}

extension CodeyPage where Hero == HeroCard<EmptyView> {
    /// A page whose hero is just its title (with an optional line and icon).
    init(
        _ title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        hue: CodeyColor.TopicHue? = nil,
        closes: Bool = false,
        closeID: String = "page.close",
        @ViewBuilder actions: () -> Actions = { EmptyView() },
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.init(title, closes: closes, closeID: closeID, actions: actions, leading: leading) {
            HeroCard(title: title, subtitle: subtitle, icon: icon, hue: hue)
        } content: {
            content()
        }
    }
}

/// What a page is about, in its pastel: one layout everywhere (Nov 15;
/// there were four). The icon and title share the first row with the tag
/// on the right, then an optional line under the title (it wraps, so a
/// topic's description isn't cut off), then an optional bar and caption.
///
///     ╭ (icon) Title             [tag] ╮
///     │ subtitle, as long as it needs  │
///     │ ━━━━━━━━━━━━──────             │
///     ╰ caption                        ╯
struct HeroCard<Badge: View>: View {
    let title: String
    var subtitle: AttributedString?
    var icon: String?
    var hue: CodeyColor.TopicHue?
    var progress: Double?
    var caption: String?
    @ViewBuilder var badge: Badge
    @Environment(\.appHue) private var appHue

    /// `attributedSubtitle` is styled text (an exercise's task) in place
    /// of `subtitle`.
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        hue: CodeyColor.TopicHue? = nil,
        progress: Double? = nil,
        caption: String? = nil,
        attributedSubtitle: AttributedString? = nil,
        @ViewBuilder badge: () -> Badge = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = attributedSubtitle ?? subtitle.map { AttributedString($0) }
        self.icon = icon
        self.hue = hue
        self.progress = progress
        self.caption = caption
        self.badge = badge()
    }

    var body: some View {
        let hue = hue ?? appHue ?? .slate
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(alignment: .center, spacing: CodeySpacing.sm) {
                if let icon { Icon(icon, size: 26, relativeTo: .title2) }
                Text(title)
                    .font(.codeyTitle.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                badge
            }
            if let subtitle {
                Text(subtitle)
                    .font(.codeySubheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let progress {
                ProgressBar(value: progress, tint: hue.fill, height: 8, track: hue.fill.opacity(0.2))
            }
            if let caption {
                Text(caption).font(.codeySubheadline.monospacedDigit())
            }
        }
        .foregroundStyle(hue.ink)
        .padding(CodeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .codeyNote(fill: hue.soft, edge: hue.soft)
        // A pastel is light in both modes (two-tone), like GameTile.
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A round primary action for a page's button row (Save, Create, Send):
/// the filled circle, or a spinner while it works.
struct PageAction: View {
    let systemImage: String
    let label: String
    var isWorking = false
    let action: () -> Void

    var body: some View {
        if isWorking {
            ProgressView().frame(width: 44, height: 44)
        } else {
            CircleIconButton(systemImage: systemImage, label: label, kind: .filled, action: action)
        }
    }
}

/// A trigger's last frame on screen. Not observed: nothing redraws when
/// it changes; it is read only when the menu opens.
final class MenuAnchor {
    var frame = CGRect.zero
}

/// Every dropdown (§3b, Nov 15): one builder, two triggers, and the list
/// drawn by the overlay host (our note, not the system's glass menu). A
/// value picker (tier, topic, language) shows its choice as that value's
/// own tag (an outlined ⌃⌄ tag until something is chosen), and tapping it
/// opens the list again; an action menu (⋯, +) is a soft round button.
struct CodeyMenu: View {
    enum Trigger {
        /// The chosen value, drawn as the same tag it is everywhere else
        /// (a tier tag for a tier, the language tag for a language).
        case value(String, systemImage: String? = nil, variant: CodeyChipVariant = .neutral)
        /// Nothing chosen yet: an outlined tag with ⌃⌄.
        case placeholder(String, color: Color = CodeyColor.brand)
        /// A round button; `compact` is tag height, for menus inside a
        /// card next to its tags.
        case icon(String, label: String, compact: Bool = false)
    }

    let trigger: Trigger
    let items: () -> [CodeyMenuItem]
    @Environment(CodeyOverlay.self) private var overlay: CodeyOverlay?
    /// Where the trigger is, for the list to open from. A plain box, so
    /// the frame updating as the page scrolls never redraws the trigger.
    @State private var anchor = MenuAnchor()

    init(_ trigger: Trigger, @CodeyMenuBuilder items: @escaping () -> [CodeyMenuItem]) {
        self.trigger = trigger
        self.items = items
    }

    var body: some View {
        Button {
            overlay?.present(menu: items(), from: anchor.frame)
        } label: {
            switch trigger {
            case let .value(title, systemImage, variant):
                CodeyChip(title, systemImage: systemImage, variant: variant)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                    .accessibilityHint("Changes it")
            case let .placeholder(title, color):
                CodeyChip(title, systemImage: "chevron.up.chevron.down", variant: .outline(color))
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            case let .icon(systemImage, label, compact):
                CircleIcon(systemImage: systemImage, kind: .soft, compact: compact)
                    .accessibilityLabel(label)
            }
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { anchor.frame = $0 }
    }
}

/// The pill at the top left of a page (S41): Play's streak, how many
/// decks or topics, Groups' XP this week. A number with its icon, in a soft tint.
struct HeaderBadge: View {
    let value: Int
    let icon: String
    let ink: Color
    let fill: Color
    /// "430 XP"; nil shows the number alone.
    var unit: String?

    var body: some View {
        Label(unit.map { "\(value.formatted()) \($0)" } ?? value.formatted(), icon: icon)
            .font(.codeyHeadline.monospacedDigit())
            .foregroundStyle(ink)
            .contentTransition(.numericText(value: Double(value)))
            .padding(.horizontal, CodeySpacing.md)
            .frame(height: 44)
            .background(fill, in: .pill)
    }
}

/// A tab page's search (Decks, Library): the round button that opens and
/// closes it, and the field under the buttons. Closing clears the text.
struct PageSearchButton: View {
    @Binding var isSearching: Bool
    @Binding var text: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        CircleIconButton(systemImage: isSearching ? "xmark" : "magnifyingglass", label: isSearching ? "Close search" : "Search", kind: .soft) {
            withAnimation(CodeyMotion.snappy) {
                isSearching.toggle()
                if !isSearching { text = "" }
            }
            focus.wrappedValue = isSearching
        }
    }
}

struct PageSearchField: View {
    let prompt: String
    @Binding var text: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: CodeySpacing.sm) {
            Icon("magnifyingglass", size: 18, relativeTo: .body)
                .foregroundStyle(CodeyColor.textSecondary)
            TextField(prompt, text: $text)
                .font(.codeyBody)
                .focused(focus)
                .submitLabel(.search)
        }
        .padding(.horizontal, CodeySpacing.md)
        .frame(minHeight: 44)
        .background(CodeyColor.surfaceRaised, in: .pill)
        .overlay { RoundedRectangle.pill.strokeBorder(CodeyColor.separator, lineWidth: 1) }
        .transition(.opacity)
    }
}
