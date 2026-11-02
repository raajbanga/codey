import SwiftUI

// Home's building blocks (HomeView lays them out).

/// Level, XP, and streak above a thin progress line, then today's goal.
/// No card: the greeting and this summary read as one header block.
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
                    Label("Goal met", systemImage: "checkmark.circle.fill")
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
                            Image(systemName: systemImage)
                                .font(.codeyHeadline)
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

/// A section heading above a Home note.
struct HomeSectionTitle: View {
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

/// A row inside a Home note: icon, title, subtitle (plus optional extra
/// content such as a progress bar), and a trailing chevron. The caller
/// wraps it in a Button or NavigationLink.
struct ChevronRow<Extra: View>: View {
    let systemImage: String
    var tint: Color = CodeyColor.brand
    let title: String
    let subtitle: String
    @ViewBuilder var extra: Extra

    var body: some View {
        HStack(spacing: CodeySpacing.sm) {
            HomeRowIcon(systemName: systemImage, tint: tint)
            VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                Text(title)
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.codeySubheadline)
                    .monospacedDigit()
                    .foregroundStyle(CodeyColor.textSecondary)
                extra
            }
            Spacer(minLength: 0)
            RowChevron()
        }
        .padding(.vertical, CodeySpacing.md)
        .contentShape(.rect)
    }
}

extension ChevronRow where Extra == EmptyView {
    init(systemImage: String, tint: Color = CodeyColor.brand, title: String, subtitle: String) {
        self.init(systemImage: systemImage, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
    }
}

private struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.codeyCallout.weight(.semibold))
            .foregroundStyle(CodeyColor.textSecondary)
            .accessibilityHidden(true)
    }
}

/// The leading symbol of a Home row, in a fixed-width column so titles line
/// up whatever the symbol's width (person.3 is much wider than f(x)).
struct HomeRowIcon: View {
    let systemName: String
    var tint: Color = CodeyColor.brand

    @ScaledMetric(relativeTo: .callout) private var width: CGFloat = 32

    var body: some View {
        Image(systemName: systemName)
            .font(.codeyCallout)
            .foregroundStyle(tint)
            .frame(width: width)
            .accessibilityHidden(true)
    }
}

/// One topic on Home, as its own note: title, mastery + accuracy, and the
/// two ways to practice it: Cards (flashcards) and Quiz.
struct TopicNote: View {
    let topic: Topic
    let isPinned: Bool
    let decks: [FlashcardDeck]
    let snapshotDeckIDs: Set<UUID>
    let accuracy: Double?
    /// (deck, resume?)
    let practice: (FlashcardDeck, Bool) -> Void
    let quiz: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.md) {
            VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                HStack(spacing: CodeySpacing.sm) {
                    HomeRowIcon(systemName: topic.iconName)
                    Text(topic.title)
                        .font(.codeyHeadline)
                        .foregroundStyle(CodeyColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if isPinned {
                        Image(systemName: "pin")
                            .font(.codeyCaption)
                            .foregroundStyle(CodeyColor.textSecondary)
                            .accessibilityLabel("Pinned")
                    }
                }
                Text(statsLine)
                    .font(.codeySubheadline)
                    .foregroundStyle(CodeyColor.textSecondary)
            }
            HStack(spacing: CodeySpacing.sm) {
                Group {
                    if decks.isEmpty {
                        Spacer(minLength: 0)
                    } else {
                        ProgressBar(value: progressRate)
                            .accessibilityLabel("Flashcard progress")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.trailing, CodeySpacing.sm)
                practiceButton
                CodeyButton("Quiz", compact: true, action: quiz)
                    .accessibilityIdentifier("home.topic.\(topic.title).quiz")
            }
        }
        .padding(CodeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .codeyNote()
        .accessibilityElement(children: .contain)
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
                            systemImage: deck.origin == .starter ? "sparkles" : "rectangle.stack"
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
        return parts.joined(separator: " · ")
    }
}
