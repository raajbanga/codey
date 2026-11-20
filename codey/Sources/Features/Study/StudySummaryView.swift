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
        let deltaPoints = Int((summary.progressDelta * 100).rounded())
        SessionSummary(
            title: wasEmpty ? nil : "Session complete",
            subtitle: deck.title,
            icon: "rectangle.stack",
            hue: .of(topicID: deck.topicId),
            progress: summary.endProgressRate,
            // S19: progress in mastery points, so a first pass shows what changed.
            caption: "\(Int((summary.endProgressRate * 100).rounded()))% progress, \(deltaPoints > 0 ? "+" : "")\(deltaPoints) pts",
            xpEarned: wasEmpty ? nil : summary.xpEarned,
            stats: wasEmpty ? [] : [
                SummaryStat(value: summary.reviewed, label: reviewedLabel, systemImage: "rectangle.on.rectangle"),
                SummaryStat(value: summary.movedUp, label: "Moved up", systemImage: "arrow.up.circle.fill", tint: CodeyColor.success),
            ] + (summary.newlyMastered > 0 ? [SummaryStat(value: summary.newlyMastered, label: "Mastered", systemImage: "checkmark.seal.fill", tint: CodeyColor.success)] : []),
            againTitle: "Study Again",
            againID: "study.again",
            doneID: "study.done",
            again: wasEmpty ? nil : studyAgain,
            done: done,
            celebration: summary.unlockedTiers.last.map { ("\($0.style.label) unlocked!", $0.style.symbol) }
        ) {
            if wasEmpty {
                EmptyStateView(systemImage: "checkmark.seal.fill", title: "All caught up", message: emptyMessage)
            } else {
                ForEach(summary.unlockedTiers, id: \.self) { TierUnlockedBanner(tier: $0) }
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
