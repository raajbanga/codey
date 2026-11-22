import SwiftData
import SwiftUI

/// The trophy case (FR-35, Nov 21), opened from Play's streak pill: every
/// badge in a grid of square bento tiles, earned ones full size in their
/// pastel, locked ones a smaller grey silhouette with what they pay.
/// Tapping either opens it in a floating panel.
///
///     ╭ (🏆) Badges       [# Achievements] ╮
///     │ ━━━━━━━━━━──────────                │
///     ╰ 6 of 27 Unlocked                    ╯
///     ╭    ⬡    ╮ ╭    ⬡    ╮ ╭[+150 XP]╮
///     │ Reached │ │ Reached │ │    ▪    │   ← 3 a row on iPhone, 4 on
///     ╰ Level 2 ╯ ╰ Level 5 ╯ ╰─────────╯     iPad portrait, 6 landscape
struct BadgesView: View {
    @Environment(\.modelContext) private var context
    @Query private var awards: [BadgeAward]
    /// Every count the badges look at, for a locked badge's progress.
    @State private var facts = BadgeFacts()
    @State private var selected: Badge?

    /// When each earned badge was earned.
    private var earned: [Badge: Date] {
        Dictionary(awards.compactMap { award in award.badge.map { ($0, award.earnedAt) } }, uniquingKeysWith: min)
    }

    var body: some View {
        let earned = earned
        let total = Badge.allCases.count
        CodeyPage("Badges", hero: {
            HeroCard(
                title: "Badges",
                icon: "trophy",
                progress: Double(earned.count) / Double(total),
                caption: "\(earned.count) of \(total) Unlocked"
            ) {
                CodeyChip("Achievements", systemImage: "number", variant: .xp)
            }
        }, content: {
            BentoGrid(columns: .badges) {
                ForEach(Badge.allCases) { badge in
                    Button {
                        selected = badge
                    } label: {
                        BadgeTile(badge: badge, earnedAt: earned[badge], facts: facts)
                    }
                    .buttonStyle(TilePressStyle())
                    .accessibilityIdentifier("badges.\(badge.rawValue)")
                }
            }
        })
        .floatingPanel(item: $selected) { badge in
            BadgeDetail(badge: badge, earnedAt: earned[badge], facts: facts)
        }
        .task(id: awards.count) {
            facts = (try? BadgeEvaluator.facts(in: context)) ?? BadgeFacts()
        }
    }
}

/// One badge in the trophy case, on a square note: an earned badge and
/// what was done, or a locked one's XP over its silhouette.
private struct BadgeTile: View {
    let badge: Badge
    let earnedAt: Date?
    let facts: BadgeFacts

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.codeyLayout) private var layout

    private var isEarned: Bool { earnedAt != nil }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // An earned badge's line this large doesn't fit a square:
                // the tile grows.
                content.padding(.bottom, CodeySpacing.sm)
            } else {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay { content }
            }
        }
        .frame(maxWidth: .infinity)
        .codeyNote()
        .contentShape(.rect(cornerRadius: CodeyRadius.lg))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isEarned ? badge.title : badge.requirement)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Shows the badge")
    }

    @ViewBuilder private var content: some View {
        if isEarned {
            VStack(spacing: CodeySpacing.xs) {
                BadgeArt(style: badge.art)
                    .padding(.horizontal, CodeySpacing.xs)
                    .frame(maxHeight: typeSize.isAccessibilitySize ? 72 : .infinity)
                Text(badge.title)
                    .font(.codeyCaption.weight(.semibold))
                    .foregroundStyle(CodeyColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, CodeySpacing.md)
            .padding([.horizontal, .bottom], CodeySpacing.sm)
        } else {
            // Locked: what it pays over the grey silhouette, both centered
            // (a corner tag crowds a tile this small), the badge a little
            // smaller than an earned one. What it takes is in the panel
            // (and VoiceOver's label).
            VStack(spacing: CodeySpacing.sm) {
                CodeyChip(xp: badge.xp)
                BadgeArt(style: badge.art, isEarned: false)
                    .padding(.horizontal, CodeySpacing.sm)
                    .frame(maxHeight: typeSize.isAccessibilitySize ? 52 : .infinity)
            }
            .padding(layout.cardPadding)
        }
    }

    private var accessibilityValue: String {
        if let earnedAt { return "Unlocked \(earnedAt.formatted(date: .abbreviated, time: .omitted))" }
        let progress = badge.progress(facts)
        return "Locked. \(progress.value) of \(progress.target). Plus \(badge.xp) XP"
    }
}

/// A badge opened (in a floating panel, like quiz setup): the badge in its
/// colors on a note, then two bentos side by side: when it was earned and
/// the XP it paid, or how far along it is and what it will pay.
private struct BadgeDetail: View {
    let badge: Badge
    let earnedAt: Date?
    let facts: BadgeFacts

    @Environment(\.codeyLayout) private var layout
    @ScaledMetric(relativeTo: .largeTitle) private var artSize: CGFloat = 128

    var body: some View {
        let progress = badge.progress(facts)
        VStack(spacing: layout.gridGap) {
            VStack(spacing: CodeySpacing.sm) {
                BadgeArt(style: badge.art)
                    .frame(width: artSize, height: artSize)
                Text(earnedAt == nil ? badge.requirement : badge.title)
                    .font(.codeyTitle.weight(.semibold))
                    .foregroundStyle(CodeyColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Label(earnedAt == nil ? "Locked" : "Unlocked", icon: earnedAt == nil ? "lock" : "lock.open")
                    .font(.codeySubheadline)
                    .foregroundStyle(CodeyColor.textSecondary)
                if earnedAt == nil {
                    ProgressBar(value: badge.fraction(facts), tint: badge.hue.fill, height: 8, track: badge.hue.fill.opacity(0.2))
                        .padding(.top, CodeySpacing.xs)
                }
            }
            .padding(layout.cardPadding)
            .frame(maxWidth: .infinity)
            .codeyNote()
            .accessibilityElement(children: .combine)
            StatTileRow {
                if let earnedAt {
                    StatTile(text: earnedAt.formatted(.dateTime.month(.abbreviated).day().year()), label: "Earned")
                    StatTile(text: "+\(badge.xp) XP", label: "XP gained", tint: CodeyColor.xp)
                } else {
                    StatTile(text: "\(progress.value) of \(progress.target)", label: "Progress")
                    StatTile(text: "+\(badge.xp) XP", label: "On unlock", tint: CodeyColor.xp)
                }
            }
        }
        .codeyPanelPadding()
    }
}

extension View {
    /// Shows the quiet celebration banner when a new badge is awarded while
    /// this view is on screen (S9: no particles). `isActive` is false for a
    /// view hidden under a full-screen cover, so the banner shows once, on
    /// the cover, not twice.
    func badgeBanner(isActive: Bool = true) -> some View {
        modifier(BadgeBannerModifier(isActive: isActive))
    }
}

private struct BadgeBannerModifier: ViewModifier {
    let isActive: Bool

    @Query(sort: \BadgeAward.earnedAt) private var awards: [BadgeAward]
    /// Badges already on record when this view appeared, plus any shown
    /// since; nil until first appearance.
    @State private var seen: Set<String>?
    @State private var badge: Badge?
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if let badge {
                    CelebrationOverlay(isPresented: $isPresented, title: "\(badge.title) +\(badge.xp) XP", systemImage: badge.symbol)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                if seen == nil { seen = Set(awards.map(\.badgeRaw)) }
            }
            .onChange(of: awards.map(\.badgeRaw)) { _, raws in
                let new = raws.filter { !(seen ?? []).contains($0) }
                seen = Set(raws)
                // Only one earned just now: a badge pulled from another
                // device (S43) arrives with its old date and isn't news.
                guard isActive, let raw = new.last, let earned = Badge(rawValue: raw),
                      let award = awards.first(where: { $0.badgeRaw == raw }),
                      award.earnedAt > .now.addingTimeInterval(-60) else { return }
                badge = earned
                isPresented = true
            }
    }
}

#Preview {
    NavigationStack {
        BadgesView()
    }
    .modelContainer(ModelContainerFactory.makePreview())
}
