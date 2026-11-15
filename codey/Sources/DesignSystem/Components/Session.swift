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
    /// Off on the summary: just ✕.
    var isActive = true
    let close: () -> Void
    @ViewBuilder var progress: Progress
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: CodeySpacing.sm) {
            CloseButton(label: closeLabel, hint: closeHint, action: close)
                .accessibilityIdentifier(closeID)
            if isActive {
                progress
                trailing
            } else {
                Spacer()
            }
        }
        .padding(.vertical, CodeySpacing.xs)
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

/// End of a quiz or study session: a hero (score ring or icon), a title and
/// line, the XP earned, details (stat tiles, banners), then Again / Done
/// pinned at the bottom, with one quiet celebration.
struct SessionSummary<Hero: View, Details: View>: View {
    var title: String?
    var subtitle: String?
    /// nil hides the XP pill (practice, nothing to study).
    var xpEarned: Int?
    let againTitle: String
    let againID: String
    let doneID: String
    /// nil hides Again.
    var again: (() -> Void)?
    let done: () -> Void
    var celebration: (title: String, symbol: String)?
    @ViewBuilder var hero: Hero
    @ViewBuilder var details: Details

    @State private var celebrating = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: CodeySpacing.lg) {
                    VStack(spacing: CodeySpacing.sm) {
                        hero
                        if let title {
                            Text(title)
                                .font(.codeyTitle.weight(.semibold))
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
            }
            .scrollBounceBehavior(.basedOnSize)
            .codeyBar(.bottom) {
                VStack(spacing: CodeySpacing.sm) {
                    if let again {
                        CodeyButton(againTitle, systemImage: "arrow.clockwise", kind: .secondary, fullWidth: true, action: again)
                            .accessibilityIdentifier(againID)
                    }
                    CodeyButton("Done", kind: .primary, fullWidth: true, action: done)
                        .accessibilityIdentifier(doneID)
                }
                .padding(.bottom, CodeySpacing.sm)
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
