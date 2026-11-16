import SwiftUI

// Home's building blocks (HomeView lays them out).

/// One topic (S41 mockup): a GameTile in the topic's color with what a
/// question pays, its accuracy bar, and an action. On Play the tag is its
/// top tier and the action plays; in the Library the tags count its
/// exercises and decks (like a deck's card count) and the action opens it.
struct TopicTile: View {
    let stats: QuizTopicStats
    /// Exercises and decks, shown instead of the tier (Library).
    var counts: (exercises: Int, decks: Int)?
    var action = TileAction("Play")
    let open: () -> Void

    private var topic: Topic { stats.topic }

    /// The hardest unlocked tier sets the quoted reward.
    private var bestTier: Difficulty {
        stats.tiers.last(where: \.isUnlocked)?.difficulty ?? .easy
    }

    var body: some View {
        Button(action: open) {
            GameTile(
                icon: topic.iconName,
                title: topic.title,
                hue: .of(topicID: topic.id),
                // FR-37: accuracy over the last answers (empty before the first).
                progress: stats.accuracy ?? 0,
                action: action
            ) {
                CodeyChip(xp: XPPolicy.base(bestTier))
            } tags: {
                if let counts {
                    // Worded like a deck's "6 cards"; the decks drop out
                    // when both don't fit.
                    let exercises = CodeyChip(counts.exercises.counted("exercise"), systemImage: "chevron.left.forwardslash.chevron.right")
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: CodeySpacing.xs) {
                            exercises
                            CodeyChip(counts.decks.counted("deck"), systemImage: "rectangle.stack")
                        }
                        exercises
                    }
                } else {
                    CodeyChip(tier: bestTier)
                }
            }
        }
        .buttonStyle(TilePressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        let accuracy = stats.accuracy.map { "\($0.percentText) correct. " } ?? ""
        guard let counts else {
            return "Play \(topic.title). \(accuracy)\(bestTier.style.label) tier, \(XPPolicy.base(bestTier)) XP a question"
        }
        return "\(topic.title). \(accuracy)\(counts.exercises.counted("exercise")), \(counts.decks.counted("deck"))"
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
    @Environment(\.codeyLayout) private var layout

    private var filled: Bool { isLarge && !isPaid }

    var body: some View {
        Group {
            if isLarge { large } else { small }
        }
        .padding(isLarge ? layout.cardPadding : layout.gridGap)
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

