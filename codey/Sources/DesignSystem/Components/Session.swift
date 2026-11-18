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
