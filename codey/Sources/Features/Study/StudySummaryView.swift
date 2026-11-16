import SwiftData
import SwiftUI

/// End of a study session: what changed and the XP earned, then Study
/// Again / Done. Laid out by SessionSummary, as the quiz summary is.
struct StudySummaryView: View {
    let deck: FlashcardDeck
    let summary: StudySessionViewModel.Summary
    /// Nothing was available to study (e.g. every unlocked card is retired).
    let wasEmpty: Bool
    let studyAgain: () -> Void
    let done: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        SessionSummary(
            title: wasEmpty ? nil : "Session complete",
            subtitle: wasEmpty ? nil : deck.title,
            xpEarned: wasEmpty ? nil : summary.xpEarned,
            againTitle: "Study Again",
            againID: "study.again",
            doneID: "study.done",
            again: wasEmpty ? nil : studyAgain,
            done: done,
            celebration: summary.unlockedTiers.last.map { ("\($0.style.label) unlocked!", $0.style.symbol) }
        ) {
            if !wasEmpty {
                SessionSummaryIcon(systemImage: "rectangle.stack", hue: .of(topicID: deck.topicId))
            }
        } details: {
            if wasEmpty {
                EmptyStateView(systemImage: "checkmark.seal.fill", title: "All caught up", message: emptyMessage)
            } else {
                stats
                ForEach(summary.unlockedTiers, id: \.self) { TierUnlockedBanner(tier: $0) }
            }
        }
    }

    /// S19: "moved up" and deck progress in mastery points, so a first pass
    /// through a deck shows what changed instead of "0 mastered, 0%".
    private var stats: some View {
        let endPercent = Int((summary.endProgressRate * 100).rounded())
        let deltaPoints = Int((summary.progressDelta * 100).rounded())
        let delta = deltaPoints > 0 ? "+\(deltaPoints)" : "\(deltaPoints)"
        return VStack(spacing: CodeySpacing.md) {
            StatTileRow {
                StatTile(value: summary.reviewed, label: reviewedLabel, systemImage: "rectangle.on.rectangle")
                StatTile(value: summary.movedUp, label: "Moved up", systemImage: "arrow.up.circle.fill", tint: CodeyColor.success)
                StatTile(value: endPercent, label: "Progress, \(delta) pts", suffix: "%", systemImage: "chart.line.uptrend.xyaxis")
            }
            if summary.newlyMastered > 0 {
                CodeyChip(
                    "\(summary.newlyMastered.counted("card")) mastered",
                    systemImage: "checkmark.seal.fill",
                    variant: .success
                )
            }
        }
    }

    private var reviewedLabel: String {
        summary.repeats > 0 ? "Reviewed, +\(summary.repeats.counted("repeat"))" : "Cards reviewed"
    }

    private var emptyMessage: String {
        guard deck.origin == .starter else {
            return "This deck has no cards to study."
        }
        let profile: UserProfile? = try? modelContext.first()
        let locked = TierGate.availability(
            tallies: TierGate.tallies(for: deck),
            xp: profile?.totalXP,
            level: profile?.level ?? 1
        ).first { !$0.isUnlocked }
        if let locked, let reason = locked.lockReason {
            return "You've mastered every card you've unlocked. \(locked.difficulty.style.label) is next: \(reason)."
        }
        return "You've mastered every card in this deck. Mastered starter cards retire."
    }
}
