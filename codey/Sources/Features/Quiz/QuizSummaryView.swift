import SwiftUI

/// End of a quiz: percentage ring + "8/10 correct" (FR-20), XP / streak /
/// retired tiles, and level-up / tier-unlock banners with a celebration.
struct QuizSummaryView: View {
    let viewModel: QuizViewModel
    let done: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrating = false
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 148

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: CodeySpacing.lg) {
                    score
                    tiles
                    banners
                }
                .padding(CodeySpacing.md)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { buttons }

            if let celebration {
                CelebrationOverlay(isPresented: $celebrating, title: celebration.title, systemImage: celebration.symbol)
            }
        }
        .onAppear {
            if celebration != nil { celebrating = true }
        }
    }

    private var score: some View {
        VStack(spacing: CodeySpacing.sm) {
            ProgressRing(value: viewModel.percentCorrect, lineWidth: 14, tint: ringTint) {
                Text(viewModel.percentCorrect, format: .percent.precision(.fractionLength(0)))
                    .font(.codeyNumeric)
                    .foregroundStyle(CodeyColor.textPrimary)
            }
            .frame(width: ringSize, height: ringSize)
            .accessibilityLabel("Score")
            Text("\(viewModel.correctCount)/\(viewModel.questions.count) correct")
                .font(.codeyTitle)
            Text(viewModel.isPractice ? "\(viewModel.topic.title) · review practice" : viewModel.topic.title)
                .font(.codeyCallout)
                .foregroundStyle(CodeyColor.textSecondary)
        }
        .padding(.top, CodeySpacing.md)
    }

    private var tiles: some View {
        StatTileRow {
            if !viewModel.isPractice {
                StatTile(value: viewModel.xpEarned, label: "XP earned", suffix: " XP", systemImage: "star.fill")
            }
            StatTile(value: viewModel.bestStreak, label: "Best streak", systemImage: "flame.fill", tint: CodeyColor.warning)
            if !viewModel.isPractice {
                StatTile(value: viewModel.newlyRetired, label: "Newly retired", systemImage: "checkmark.seal.fill", tint: CodeyColor.success)
            }
        }
    }

    @ViewBuilder
    private var banners: some View {
        if let level = viewModel.reachedLevel {
            CodeyCard(tint: CodeyColor.brand) {
                Label("Level \(level)!", systemImage: "arrow.up.circle.fill")
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.brand)
            }
        }
        ForEach(viewModel.unlockedTiers, id: \.self) { TierUnlockedBanner(tier: $0) }
    }

    private var buttons: some View {
        VStack(spacing: CodeySpacing.sm) {
            CodeyButton("Quiz Again", systemImage: "arrow.clockwise", kind: .secondary, fullWidth: true) {
                withCodeyAnimation(reduceMotion: reduceMotion) { viewModel.restart() }
            }
            .accessibilityIdentifier("quiz.again")
            CodeyButton("Done", kind: .primary, fullWidth: true, action: done)
                .accessibilityIdentifier("quiz.done")
        }
        .padding(.horizontal, CodeySpacing.md)
        .padding(.bottom, CodeySpacing.sm)
    }

    private var ringTint: Color {
        switch viewModel.percentCorrect {
        case 0.8...: CodeyColor.success
        case 0.5..<0.8: CodeyColor.brand
        default: CodeyColor.warning
        }
    }

    /// Level-up wins over a tier unlock; one burst per summary (D17).
    private var celebration: (title: String, symbol: String)? {
        if let level = viewModel.reachedLevel { return ("Level \(level)!", "arrow.up.circle.fill") }
        if let tier = viewModel.unlockedTiers.last { return ("\(tier.style.label) unlocked!", tier.style.symbol) }
        return nil
    }
}
