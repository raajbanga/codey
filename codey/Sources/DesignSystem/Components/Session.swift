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

/// A summary's hero when it isn't a score: the session's symbol on its
/// topic's pastel (a study deck, a solved exercise), so the end screens match.
struct SessionSummaryIcon: View {
    let systemImage: String
    let hue: CodeyColor.TopicHue
    @Environment(\.codeyLayout) private var layout

    var body: some View {
        let side: CGFloat = layout.isRegular ? 112 : 72
        Icon(systemImage, size: side * 0.55, relativeTo: .largeTitle)
            .foregroundStyle(hue.ink)
            .frame(width: side, height: side)
            .background(hue.soft, in: .codey(CodeyRadius.lg))
            .accessibilityHidden(true)
    }
}

/// End of a quiz or study session: a hero (score ring or icon), a title and
/// line, the XP earned, details (stat tiles, banners), then Again / Done
/// pinned at the bottom, with one quiet celebration.
struct SessionSummary<Hero: View, Details: View>: View {
    var title: String?
    var subtitle: String?
    /// nil hides the XP pill (practice, nothing to study).
    var xpEarned: Int?
    let againTitle: String
    /// "Quiz Again" restarts; an exercise's "Next Challenge" moves on.
    var againSystemImage = "arrow.clockwise"
    let againID: String
    let doneID: String
    /// nil hides Again.
    var again: (() -> Void)?
    let done: () -> Void
    var celebration: (title: String, symbol: String)?
    @ViewBuilder var hero: Hero
    @ViewBuilder var details: Details

    @State private var celebrating = false
    @Environment(\.codeyLayout) private var layout

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: CodeySpacing.lg) {
                    VStack(spacing: CodeySpacing.sm) {
                        hero
                        if let title {
                            Text(title)
                                .font(layout.isRegular ? .codeyDisplay : .codeyTitle.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(.codeyCallout)
                                .foregroundStyle(CodeyColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        if let xpEarned {
                            CodeyChip(xp: xpEarned)
                                .accessibilityIdentifier("summary.xp")
                        }
                    }
                    .padding(.top, CodeySpacing.md)
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
