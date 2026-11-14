import SwiftUI

// Home's building blocks (HomeView lays them out).

/// Level, XP, and streak above a thin progress line, then today's goal, as
/// one wide bento tile (S40).
struct LevelSummary: View {
    let xp: Int
    let streak: Int
    /// Quiz answers + card ratings today (FR-32).
    let today: Int
    private let goal = GatingConfig.standard.dailyGoal

    private var level: Int { LevelCalculator.level(forXP: xp) }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: CodeySpacing.sm) {
                Text("Level \(level)")
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
                    .contentTransition(.numericText(value: Double(level)))
                Spacer(minLength: 0)
                Text("\(xp.formatted()) XP")
                    .font(.codeySubheadline.monospacedDigit())
                    .foregroundStyle(CodeyColor.textSecondary)
                    .contentTransition(.numericText(value: Double(xp)))
                if streak > 0 {
                    CodeyChip("\(streak)", systemImage: "flame.fill", variant: .warning)
                        .accessibilityLabel("\(streak) day streak")
                }
            }
            ProgressBar(value: LevelCalculator.progressFraction(xp))
            HStack(spacing: CodeySpacing.sm) {
                Text("\(LevelCalculator.xpToNextLevel(xp)) XP to Level \(level + 1)")
                    .foregroundStyle(CodeyColor.textSecondary)
                Spacer(minLength: 0)
                if today >= goal {
                    Label("Goal met", icon: "checkmark.circle.fill")
                        .foregroundStyle(CodeyColor.success)
                } else {
                    Text("Today \(today)/\(goal)")
                        .monospacedDigit()
                        .foregroundStyle(CodeyColor.textSecondary)
                }
            }
            .font(.codeySubheadline)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(CodeySpacing.md)
        .codeyNote()
        .codeyAnimation(CodeyMotion.snappy, value: xp)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Level \(level), \(xp) XP, \(LevelCalculator.xpToNextLevel(xp)) to the next level. "
                + (today >= goal ? "Daily goal met" : "Daily goal \(today) of \(goal)")
                + (streak > 0 ? ", \(streak) day streak" : "")
        )
    }
}

/// The one tappable suggestion on Home. The whole card is the button.
struct UpNextCard: View {
    let eyebrow: String
    let title: String
    let detail: String
    let systemImage: String
    var progress: Double?
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 48

    var body: some View {
        Button(action: action) {
            HStack(spacing: CodeySpacing.md) {
                Group {
                    if let progress {
                        ProgressRing(value: progress, lineWidth: 4) {
                            Icon(systemImage, size: 18, relativeTo: .headline)
                                .foregroundStyle(CodeyColor.brand)
                        }
                    } else {
                        IconTile(systemName: systemImage, size: iconSize)
                    }
                }
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                    Text(eyebrow)
                        .font(.codeySubheadline.weight(.medium))
                        .foregroundStyle(CodeyColor.brand)
                    Text(title)
                        .font(.codeyHeadline)
                        .foregroundStyle(CodeyColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .font(.codeySubheadline)
                        .foregroundStyle(CodeyColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                RowChevron()
            }
            .padding(CodeySpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .codeyNote(fill: CodeyColor.brandSoft, edge: CodeyColor.brandFill)
            .contentShape(.rect(cornerRadius: CodeyRadius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eyebrow): \(title). \(detail)")
        .accessibilityIdentifier("home.upNext")
    }
}

/// One topic on Home as a bento tile: mastery + accuracy, and the two ways
/// to practice it: Cards (flashcards) and Quiz.
struct TopicTile: View {
    let topic: Topic
    let isPinned: Bool
    let decks: [FlashcardDeck]
    let snapshotDeckIDs: Set<UUID>
    let accuracy: Double?
    /// (deck, resume?)
    let practice: (FlashcardDeck, Bool) -> Void
    let quiz: () -> Void

    var body: some View {
        BentoTile(icon: topic.iconName, title: topic.title, detail: statsLine) {
            if isPinned {
                Icon("pin", size: 16, relativeTo: .caption)
                    .foregroundStyle(CodeyColor.textSecondary)
                    .accessibilityLabel("Pinned")
                    .accessibilityHidden(false)
            }
        } footer: {
            VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                if !decks.isEmpty {
                    ProgressBar(value: progressRate)
                        .accessibilityLabel("Flashcard progress")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: CodeySpacing.xs) { buttons }
                    VStack(alignment: .leading, spacing: CodeySpacing.xs) { buttons }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var buttons: some View {
        practiceButton
        CodeyButton("Quiz", compact: true, action: quiz)
            .accessibilityIdentifier("home.topic.\(topic.title).quiz")
    }

    /// One deck → a button. Several → a menu of decks. None → disabled.
    @ViewBuilder
    private var practiceButton: some View {
        if decks.count > 1 {
            Menu {
                ForEach(decks) { deck in
                    Button {
                        practice(deck, snapshotDeckIDs.contains(deck.id))
                    } label: {
                        Label(
                            snapshotDeckIDs.contains(deck.id) ? "\(deck.title) (continue)" : deck.title,
                            icon: deck.origin == .starter ? "sparkles" : "rectangle.stack"
                        )
                    }
                }
            } label: {
                practiceLabel
            }
            .buttonStyle(CodeyFillButtonStyle(kind: .secondary, compact: true))
            .accessibilityHint("Choose a deck to study")
            .accessibilityIdentifier("home.topic.\(topic.title).practice")
        } else {
            Button {
                if let deck = decks.first { practice(deck, snapshotDeckIDs.contains(deck.id)) }
            } label: {
                practiceLabel
            }
            .buttonStyle(CodeyFillButtonStyle(kind: .secondary, compact: true))
            .disabled(decks.isEmpty)
            .accessibilityIdentifier("home.topic.\(topic.title).practice")
        }
    }

    private var practiceLabel: some View {
        Text("Cards")
            .lineLimit(1)
            .accessibilityLabel("Practice with flashcards")
    }

    /// Mastery points over all this topic's decks (S19, as
    /// FlashcardDeck.progressRate).
    private var progressRate: Double {
        var total = 0, points = 0
        for card in decks.lazy.flatMap(\.unorderedActiveCards) {
            total += 1
            points += card.masteryScore
        }
        return total == 0 ? 0 : Double(points) / Double(total * Flashcard.maxMastery)
    }

    private var statsLine: String {
        var parts: [String] = []
        if !decks.isEmpty { parts.append("\(progressRate.percentText) progress") }
        parts.append(accuracy.map { "\($0.percentText) accuracy" } ?? "No quizzes yet")
        return parts.joined(separator: "\n")
    }
}
