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

/// What a page is about, in its pastel (S41 deck card, shared Nov 15): an
/// icon with a short line beside it and a badge, the title, and an
/// optional progress bar with its caption. Deck detail, Play (name and level), Profile,
/// Groups and every other page open with one.
struct HeroCard<Badge: View>: View {
    let title: String
    var subtitle: String?
    var detail: AttributedString?
    var icon: String?
    var hue: CodeyColor.TopicHue?
    var progress: Double?
    var caption: String?
    @ViewBuilder var badge: Badge
    @Environment(\.appHue) private var appHue

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        hue: CodeyColor.TopicHue? = nil,
        progress: Double? = nil,
        caption: String? = nil,
        /// Longer styled text (an exercise's prompt) under the title;
        /// `subtitle` is a short line beside the icon.
        attributedSubtitle: AttributedString? = nil,
        @ViewBuilder badge: () -> Badge = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.detail = attributedSubtitle
        self.icon = icon
        self.hue = hue
        self.progress = progress
        self.caption = caption
        self.badge = badge()
    }

    var body: some View {
        let hue = hue ?? appHue ?? .slate
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            if titleBesideIcon {
                // Just a title: it sits beside the icon, at the icon's
                // size (Nov 15).
                HStack(alignment: .center, spacing: CodeySpacing.sm) {
                    if let icon { Icon(icon, size: 26, relativeTo: .title2) }
                    titleText
                    Spacer(minLength: 0)
                    badge
                }
            } else {
                // Icon, the short line, and the badge share one row, so
                // the title sits one line higher.
                if icon != nil || subtitle != nil || Badge.self != EmptyView.self {
                    HStack(alignment: .center, spacing: CodeySpacing.sm) {
                        if let icon { Icon(icon, size: 26, relativeTo: .title2) }
                        if let subtitle {
                            Text(subtitle)
                                .font(.codeySubheadline)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        badge
                    }
                }
                titleText
            }
            if let detail {
                Text(detail)
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

    private var titleBesideIcon: Bool { icon != nil && subtitle == nil && detail == nil }

    private var titleText: some View {
        Text(title)
            .font(.codeyTitle.weight(.semibold))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
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
    @State private var anchor = CGRect.zero

    init(_ trigger: Trigger, @CodeyMenuBuilder items: @escaping () -> [CodeyMenuItem]) {
        self.trigger = trigger
        self.items = items
    }

    var body: some View {
        Button {
            overlay?.present(menu: items(), from: anchor)
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
        .codeyAnchor($anchor)
    }
}
