import SwiftUI

// Quiz and study are both focus-mode sessions (S41): the same bar on top
// and the same summary at the end, so they read as one kind of screen.

/// ✕, the session's progress, then trailing items (XP so far, Ask AI).
///
///     (✕)  ▮▮▮▯▯▯▯▯   +20 XP  (✦)
struct SessionTopBar<Progress: View, Trailing: View>: View {
    let closeLabel: String
    var closeHint: String?
    let closeID: String
    let close: () -> Void
    @ViewBuilder var progress: Progress
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: CodeySpacing.sm) {
            CloseButton(label: closeLabel, hint: closeHint, action: close)
                .accessibilityIdentifier(closeID)
            progress
            trailing
        }
        .padding(.vertical, CodeySpacing.xs)
    }
}

/// The session's progress in the top bar, shared by quiz and study (§3b) so
/// the two read the same: one 6 pt tick per item, finished ones in their
/// result's color, the current one brand, the rest in the dot-grid ink.
/// Past `maxSegments` the ticks would be slivers, so it draws one
/// continuous bar of the same height and track instead.
///
///     ▮▮▮▮▯▯▯▯   (green, green, red, brand, then dot ink)
struct SessionProgress: View {
    /// Colors of the finished items, in order.
    let done: [Color]
    let total: Int
    let accessibilityLabel: String
    var accessibilityValue: String = ""

    nonisolated static let height: CGFloat = 6
    static let maxSegments = 30

    var body: some View {
        let colors = segmentColors
        Group {
            if total <= Self.maxSegments {
                HStack(spacing: CodeySpacing.xxs) {
                    // @Sendable: built off the main thread like MasteryDots (BUG-04).
                    ForEach(colors.indices, id: \.self) { @Sendable index in
                        Self.segment(colors[index])
                    }
                }
            } else {
                ProgressBar(value: total > 0 ? Double(done.count) / Double(total) : 0, height: Self.height)
            }
        }
        .frame(maxWidth: .infinity)
        .codeyAnimation(CodeyMotion.smooth, value: done.count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var segmentColors: [Color] {
        (0..<max(total, 0)).map { index in
            if index < done.count { return done[index] }
            return index == done.count ? CodeyColor.brand : CodeyColor.paperDot
        }
    }

    nonisolated private static func segment(_ color: Color) -> some View {
        RoundedRectangle.codey(CodeyRadius.xs / 2).fill(color).frame(height: Self.height)
    }
}

/// XP so far this session, in the top bar.
struct SessionXP: View {
    let amount: Int

    var body: some View {
        CodeyChip(amount > 0 ? "+\(amount) XP" : "0 XP", variant: .xp)
            .contentTransition(.numericText(value: Double(amount)))
    }
}

/// A one-line note with a colored edge under a summary's hero: a level-up
/// or a tier unlock (study and quiz summaries). Both use this one look.
struct SummaryBanner: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        CodeyCard(tint: tint) {
            Label {
                Text(title)
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
            } icon: {
                Icon(icon, relativeTo: .headline)
                    .foregroundStyle(tint)
            }
        }
    }

    static func levelUp(_ level: Int) -> SummaryBanner {
        SummaryBanner(title: "Level \(level)!", icon: "arrow.up.circle.fill", tint: CodeyColor.brand)
    }

    static func tierUnlocked(_ tier: Difficulty) -> SummaryBanner {
        SummaryBanner(title: "Tier unlocked: \(tier.style.label)", icon: tier.style.symbol, tint: tier.style.color)
    }

    /// The one celebration a summary plays: a level-up wins over a tier
    /// unlock (S9).
    static func celebration(level: Int?, unlockedTiers: [Difficulty]) -> (title: String, symbol: String)? {
        if let level { return ("Level \(level)!", "arrow.up.circle.fill") }
        if let tier = unlockedTiers.last { return ("\(tier.style.label) unlocked!", tier.style.symbol) }
        return nil
    }
}

/// One small bento under a summary's hero.
struct SummaryStat: Identifiable {
    let value: Int
    let label: String
    var suffix: String?
    let systemImage: String
    var tint: Color = CodeyColor.brand

    var id: String { label }
}

/// The end of every session (quiz, study, drill, challenge), one layout
/// (S45): a big hero bento on the topic's pastel (what happened, how far,
/// the XP), small stat bentos under it, any extras, then Again / Done
/// pinned at the bottom, with one quiet celebration.
///
///     ╭ (✓) Solved!          [+20 XP] ╮
///     │ Two Sum                        │
///     ╰ ━━━━━━━━━━━━━━━━━━━  8/8 tests ╯
///     ╭ 8         ╮ ╭ 42 ms      ╮
///     ╰ Tests     ╯ ╰ Runtime    ╯
struct SessionSummary<Details: View>: View {
    /// nil skips the hero (nothing happened: an empty study session).
    var title: String?
    var subtitle: String?
    var icon = "checkmark.seal"
    var hue: CodeyColor.TopicHue = .brand
    var progress: Double?
    var caption: String?
    /// nil hides the XP tag (practice, nothing to study).
    var xpEarned: Int?
    var stats: [SummaryStat] = []
    let againTitle: String
    /// "Quiz Again" restarts; "Next Challenge" moves on.
    var againSystemImage = "arrow.clockwise"
    let againID: String
    let doneID: String
    /// nil hides Again.
    var again: (() -> Void)?
    let done: () -> Void
    var celebration: (title: String, symbol: String)?
    @ViewBuilder var details: Details

    @State private var celebrating = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: CodeySpacing.md) {
                    if let title {
                        HeroCard(title: title, subtitle: subtitle, icon: icon, hue: hue, progress: progress, caption: caption) {
                            if let xpEarned {
                                // 0 on a repeat: said, not hidden, or it looks broken.
                                CodeyChip(xpEarned > 0 ? "+\(xpEarned) XP" : "No XP: solved before", variant: .xp)
                                    .accessibilityIdentifier("summary.xp")
                            }
                        }
                    }
                    if !stats.isEmpty {
                        StatTileRow {
                            ForEach(stats) { stat in
                                StatTile(value: stat.value, label: stat.label, suffix: stat.suffix, systemImage: stat.systemImage, tint: stat.tint)
                            }
                        }
                    }
                    details
                }
                .padding(.vertical, CodeySpacing.md)
                .codeyReadableWidth()
            }
            .scrollBounceBehavior(.basedOnSize)
            .codeyBar(.bottom) {
                VStack(spacing: CodeySpacing.sm) {
                    if let again {
                        CodeyButton(againTitle, systemImage: againSystemImage, kind: .secondary, fullWidth: true, action: again)
                            .accessibilityIdentifier(againID)
                    }
                    CodeyButton("Done", kind: .primary, fullWidth: true, action: done)
                        .accessibilityIdentifier(doneID)
                }
                .padding(.bottom, CodeySpacing.sm)
                .codeyReadableWidth()
            }

            if let celebration {
                CelebrationOverlay(isPresented: $celebrating, title: celebration.title, systemImage: celebration.symbol)
            }
        }
        .onAppear {
            if celebration != nil { celebrating = true }
        }
    }
}

/// A titled note of Markdown under a summary (a drill's explanation, a
/// challenge's editorial).
struct SummaryNote: View {
    let title: String
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            Text(title)
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textPrimary)
            CardMarkdownView(markdown: markdown)
        }
        .codeyCard()
    }
}

/// The pass / not-yet note after a drill's Check or a challenge's Run or
/// Submit: an icon, a headline, an optional detail line, and anything on
/// the trailing edge (the XP paid). Green when it passed, amber when not.
struct ResultBanner<Trailing: View>: View {
    let icon: String
    let tint: Color
    let title: String
    var detail: String?
    let passed: Bool
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: CodeySpacing.sm) {
            Icon(icon, size: 24, relativeTo: .title2)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                Text(title)
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.codeySubheadline.monospacedDigit())
                        .foregroundStyle(CodeyColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(CodeySpacing.md)
        .codeyNote(fill: passed ? CodeyColor.Soft.success : CodeyColor.Soft.warning, edge: .clear)
        .accessibilityElement(children: .combine)
    }
}

extension ResultBanner where Trailing == EmptyView {
    init(icon: String, tint: Color, title: String, detail: String? = nil, passed: Bool) {
        self.init(icon: icon, tint: tint, title: title, detail: detail, passed: passed) { EmptyView() }
    }
}

/// A caption over a block of code (a challenge example's input and output,
/// a test case's expected and actual values).
struct LabeledCodeBlock: View {
    let label: String
    let value: String
    /// Marks a wrong output.
    var highlight = false

    init(_ label: String, _ value: String, highlight: Bool = false) {
        self.label = label
        self.value = value
        self.highlight = highlight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
            Text(label)
                .font(.codeyCaption)
                .foregroundStyle(CodeyColor.textSecondary)
            Text(value)
                .font(.codeyCode)
                .foregroundStyle(highlight ? CodeyColor.danger : CodeyColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CodeySpacing.sm)
                .background(CodeyColor.codeBackground, in: .codey(CodeyRadius.md))
        }
    }
}
