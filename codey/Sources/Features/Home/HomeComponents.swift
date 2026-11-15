import SwiftUI

// Home's building blocks (HomeView lays them out).

/// One topic on Play (S41 mockup): a GameTile in the topic's color with
/// what a question pays, its top tier, its accuracy bar, and Play. The whole tile is the button.
struct PlayTopicTile: View {
    let stats: QuizTopicStats
    let inPlan: Bool
    let play: () -> Void

    private var topic: Topic { stats.topic }
    private var hue: CodeyColor.TopicHue { .of(topicID: topic.id) }

    /// The hardest unlocked tier sets the quoted reward.
    private var bestTier: Difficulty {
        stats.tiers.last(where: \.isUnlocked)?.difficulty ?? .easy
    }

    /// FR-37: the topic's accuracy over its last 50 answers (FR-36), as
    /// the tile's bar (empty before the first answer).
    private var accuracy: Double { stats.accuracy ?? 0 }

    var body: some View {
        Button(action: play) {
            GameTile(
                icon: topic.iconName,
                title: topic.title,
                hue: hue,
                progress: accuracy,
                action: TileAction("Play")
            ) {
                // What a question pays, top right like a quest's bonus.
                CodeyChip(xp: XPPolicy.base(bestTier))
            } tags: {
                CodeyChip(tier: bestTier)
                // In this week's plan: an icon tag, so it fits beside the
                // tier on a half-width tile.
                if inPlan { CodeyChip("", systemImage: "calendar", variant: .outline(hue.ink)) }
            }
        }
        .buttonStyle(TilePressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Play \(topic.title). \(stats.accuracy.map { "\($0.percentText) correct. " } ?? "")\(bestTier.style.label) tier, \(XPPolicy.base(bestTier)) XP a question\(inPlan ? ", in this week's plan" : "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("play.topic.\(topic.title).quiz")
    }
}

/// A quest on Play (S41; Nov 15 "mixed fraction" layout). The next quest
/// is large, on the left, in its pastel with Play; the other two are
/// small notes stacked on the right, together as tall as the large one.
///
///     ╭ ◎      +50 XP ╮ ╭ ⚑     +100 XP ╮
///     │ Answer 20     │ │ 15 right in…  │
///     │ 7 of 20 today │ ╰ ━━━━─────     ╯
///     │ ━━━━━━──────  │ ╭ ▭       +5 XP ╮
///     ╰ [  ▶ Play  ]  ╯ ╰ Warm up: SQL  ╯
struct QuestTile: View {
    let icon: String
    let title: String
    let detail: String
    var progress: Double?
    /// XP the quest pays; nil shows none.
    var bonus: Int?
    var isPaid = false
    let hue: CodeyColor.TopicHue
    var isLarge = false

    @Environment(\.colorScheme) private var colorScheme

    private var filled: Bool { isLarge && !isPaid }

    var body: some View {
        Group {
            if isLarge { large } else { small }
        }
        .padding(isLarge ? CodeySpacing.md : CodeySpacing.sm + CodeySpacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .codeyNote(fill: filled ? hue.soft : CodeyColor.surfaceRaised, edge: filled ? hue.soft : nil)
        // A pastel is light in both modes (two-tone), like GameTile.
        .environment(\.colorScheme, filled ? .light : colorScheme)
        .contentShape(.rect(cornerRadius: CodeyRadius.lg))
    }

    private var badge: some View {
        Group {
            if isPaid {
                CodeyChip("Done", systemImage: "checkmark", variant: .success)
            } else if let bonus {
                CodeyChip(xp: bonus)
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            HStack(spacing: CodeySpacing.xs) {
                Icon(isPaid ? "checkmark.circle.fill" : icon, size: 22, relativeTo: .title3)
                Spacer(minLength: 0)
                badge
            }
            Text(title)
                .font(.codeyHeadline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Text(isPaid ? "Bonus paid" : detail)
                .font(.codeySubheadline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: CodeySpacing.xs)
            if let progress {
                ProgressBar(value: progress, tint: hue.fill, height: 8, track: hue.fill.opacity(0.22))
            }
            if !isPaid {
                TileActionLabel(action: TileAction("Play"), hue: hue)
                    .padding(.top, CodeySpacing.xs)
            }
        }
        .foregroundStyle(filled ? hue.ink : CodeyColor.textPrimary)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            HStack(spacing: CodeySpacing.xs) {
                Icon(isPaid ? "checkmark.circle.fill" : icon, size: 20, relativeTo: .title3)
                    .foregroundStyle(isPaid ? CodeyColor.success : hue.fill)
                Spacer(minLength: 0)
                badge
            }
            Text(title)
                .font(.codeySubheadline.weight(.semibold))
                .foregroundStyle(CodeyColor.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let progress {
                ProgressBar(value: isPaid ? 1 : progress, tint: isPaid ? CodeyColor.success : hue.fill, height: 6, track: hue.fill.opacity(0.18))
            }
        }
    }
}

