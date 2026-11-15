import SwiftUI

// Home's building blocks (HomeView lays them out).

/// One topic on Play (S41 mockup): a GameTile in the topic's color, its
/// top tier, what a question pays, and Play. The whole tile is the button.
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

    var body: some View {
        Button(action: play) {
            GameTile(
                icon: topic.iconName,
                title: topic.title,
                hue: hue,
                action: TileAction("Play")
            ) {
                if inPlan { CodeyChip("This week", variant: .outline(hue.ink)) }
            } tags: {
                CodeyChip(tier: bestTier)
                CodeyChip(xp: XPPolicy.base(bestTier))
            }
        }
        .buttonStyle(TilePressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Play \(topic.title). \(bestTier.style.label) tier, \(XPPolicy.base(bestTier)) XP a question\(inPlan ? ", in this week's plan" : "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("play.topic.\(topic.title).quiz")
    }
}

/// A quest on Play (S41): a goal, the bonus it pays, and Play. The next
/// unpaid quest is marked "Up next" with the bold Play; the other keeps a
/// quiet one; a paid quest shows a check and no button.
struct QuestTile: View {
    let icon: String
    let title: String
    /// "7 of 20 today".
    let count: String
    let progress: Double
    let bonus: Int
    let isPaid: Bool
    let isNext: Bool
    let hue: CodeyColor.TopicHue

    var body: some View {
        GameTile(
            icon: isPaid ? "checkmark.circle.fill" : icon,
            title: title,
            detail: isPaid ? "Bonus paid" : count,
            hue: hue,
            filled: isNext,
            progress: progress,
            action: isPaid ? nil : TileAction("Play", prominent: isNext)
        ) {
            if isNext {
                CodeyChip("Up next", variant: .outline(hue.ink))
            } else if isPaid {
                CodeyChip("Done", systemImage: "checkmark", variant: .success)
            }
        } tags: {
            if !isPaid { CodeyChip(xp: bonus) }
        }
    }
}

/// One full-width row: icon, title, detail, chevron. The warm-up deck on
/// Play, Groups, and the like.
struct PlayRow: View {
    let icon: String
    let title: String
    let detail: String
    var tint: Color = CodeyColor.brand

    var body: some View {
        HStack(spacing: CodeySpacing.md) {
            Icon(icon, size: 24, relativeTo: .title3)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                Text(title)
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
                Text(detail)
                    .font(.codeySubheadline)
                    .foregroundStyle(CodeyColor.textSecondary)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            RowChevron()
        }
        .padding(CodeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .codeyNote()
        .contentShape(.rect(cornerRadius: CodeyRadius.lg))
        .accessibilityElement(children: .combine)
    }
}
