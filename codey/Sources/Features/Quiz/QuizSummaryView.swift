import SwiftUI

/// End of a quiz: "8/10 correct" and the score bar (FR-20), XP earned,
/// streak / retired bentos, and level-up / tier-unlock banners. Laid out by
/// SessionSummary, as the study summary is.
struct QuizSummaryView: View {
    let viewModel: QuizViewModel
    let done: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let percent = viewModel.percentCorrect
        SessionSummary(
            title: "\(viewModel.correctCount)/\(viewModel.questions.count) correct",
            subtitle: viewModel.isPractice ? "\(viewModel.topic.title), review practice" : viewModel.topic.title,
            icon: "target",
            hue: .of(topicID: viewModel.topic.id),
            progress: percent,
            caption: percent.formatted(.percent.precision(.fractionLength(0))) + " score",
            xpEarned: viewModel.isPractice ? nil : viewModel.xpEarned,
            stats: [SummaryStat(value: viewModel.bestStreak, label: "Best streak", systemImage: "flame.fill", tint: CodeyColor.warning)]
                + (viewModel.isPractice ? [] : [SummaryStat(value: viewModel.newlyRetired, label: "Newly retired", systemImage: "checkmark.seal.fill", tint: CodeyColor.success)]),
            againTitle: "Quiz Again",
            againID: "quiz.again",
            doneID: "quiz.done",
            again: { withCodeyAnimation(reduceMotion: reduceMotion) { viewModel.restart() } },
            done: done,
            celebration: celebration
        ) {
            if let level = viewModel.reachedLevel {
                CodeyCard(tint: CodeyColor.brand) {
                    Label("Level \(level)!", systemImage: "arrow.up.circle.fill")
                        .font(.codeyHeadline)
                        .foregroundStyle(CodeyColor.brand)
                }
            }
            ForEach(viewModel.unlockedTiers, id: \.self) { TierUnlockedBanner(tier: $0) }
        }
    }

    /// Level-up wins over a tier unlock; one quiet celebration per summary (S9).
    private var celebration: (title: String, symbol: String)? {
        if let level = viewModel.reachedLevel { return ("Level \(level)!", "arrow.up.circle.fill") }
        if let tier = viewModel.unlockedTiers.last { return ("\(tier.style.label) unlocked!", tier.style.symbol) }
        return nil
    }
}
