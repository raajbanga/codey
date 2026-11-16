import SwiftUI

/// End of a quiz: percentage ring + "8/10 correct" (FR-20), XP earned,
/// streak / retired tiles, and level-up / tier-unlock banners. Laid out by
/// SessionSummary, as the study summary is.
struct QuizSummaryView: View {
    let viewModel: QuizViewModel
    let done: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 148

    var body: some View {
        SessionSummary(
            title: "\(viewModel.correctCount)/\(viewModel.questions.count) correct",
            subtitle: viewModel.isPractice ? "\(viewModel.topic.title), review practice" : viewModel.topic.title,
            xpEarned: viewModel.isPractice ? nil : viewModel.xpEarned,
            againTitle: "Quiz Again",
            againID: "quiz.again",
            doneID: "quiz.done",
            again: { withCodeyAnimation(reduceMotion: reduceMotion) { viewModel.restart() } },
            done: done,
            celebration: celebration
        ) {
            ProgressRing(value: viewModel.percentCorrect, lineWidth: 14, tint: ringTint) {
                Text(viewModel.percentCorrect, format: .percent.precision(.fractionLength(0)))
                    .font(.codeyNumeric)
                    .foregroundStyle(CodeyColor.textPrimary)
            }
            .frame(width: ringSize, height: ringSize)
            .accessibilityLabel("Score")
        } details: {
            StatTileRow {
                StatTile(value: viewModel.bestStreak, label: "Best streak", systemImage: "flame.fill", tint: CodeyColor.warning)
                if !viewModel.isPractice {
                    StatTile(value: viewModel.newlyRetired, label: "Newly retired", systemImage: "checkmark.seal.fill", tint: CodeyColor.success)
                }
            }
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

    private var ringTint: Color {
        switch viewModel.percentCorrect {
        case 0.8...: CodeyColor.success
        case 0.5..<0.8: CodeyColor.brand
        default: CodeyColor.warning
        }
    }

    /// Level-up wins over a tier unlock; one quiet celebration per summary (S9).
    private var celebration: (title: String, symbol: String)? {
        if let level = viewModel.reachedLevel { return ("Level \(level)!", "arrow.up.circle.fill") }
        if let tier = viewModel.unlockedTiers.last { return ("\(tier.style.label) unlocked!", tier.style.symbol) }
        return nil
    }
}
