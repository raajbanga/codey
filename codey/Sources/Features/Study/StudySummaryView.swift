import SwiftData
import SwiftUI

/// End of a study session: what changed, then Study again / Done.
struct StudySummaryView: View {
    let deck: FlashcardDeck
    let summary: StudySessionViewModel.Summary
    /// Nothing was available to study (e.g. every unlocked card is retired).
    let wasEmpty: Bool
    let studyAgain: () -> Void
    let done: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var celebrating = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: CodeySpacing.lg) {
                    if wasEmpty {
                        EmptyStateView(
                            systemImage: "checkmark.seal.fill",
                            title: "All caught up",
                            message: emptyMessage
                        )
                    } else {
                        header
                        stats
                        unlockBanners
                    }
                }
                .padding(.top, CodeySpacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { buttons }

            if let tier = summary.unlockedTiers.last {
                CelebrationOverlay(
                    isPresented: $celebrating,
                    title: "\(tier.style.label) unlocked!",
                    systemImage: tier.style.symbol
                )
            }
        }
        .onAppear {
            if !summary.unlockedTiers.isEmpty { celebrating = true }
        }
    }

    private var header: some View {
        VStack(spacing: CodeySpacing.xs) {
            Image(systemName: "rectangle.stack.badge.person.crop.fill")
                .font(.codeyDisplay)
                .foregroundStyle(CodeyColor.brand)
                .symbolEffect(.bounce, options: .nonRepeating)
                .accessibilityHidden(true)
            Text("Session complete")
                .font(.codeyDisplay)
                .multilineTextAlignment(.center)
            Text(deck.title)
                .font(.codeyCallout)
                .foregroundStyle(CodeyColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var stats: some View {
        let endPercent = Int((summary.endMasteryRate * 100).rounded())
        let deltaPoints = Int((summary.masteryDelta * 100).rounded())
        let delta = deltaPoints > 0 ? "+\(deltaPoints)" : "\(deltaPoints)"

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: CodeySpacing.sm) { statTiles(endPercent: endPercent, delta: delta) }
            VStack(spacing: CodeySpacing.sm) { statTiles(endPercent: endPercent, delta: delta) }
        }
    }

    @ViewBuilder
    private func statTiles(endPercent: Int, delta: String) -> some View {
        StatTile(value: summary.reviewed, label: "Cards reviewed", systemImage: "rectangle.on.rectangle")
        StatTile(value: summary.newlyMastered, label: "Newly mastered", systemImage: "checkmark.seal.fill", tint: CodeyColor.success)
        StatTile(value: endPercent, label: "Deck mastery · \(delta) pts", suffix: "%", systemImage: "chart.line.uptrend.xyaxis")
    }

    @ViewBuilder
    private var unlockBanners: some View {
        ForEach(summary.unlockedTiers, id: \.self) { tier in
            CodeyCard(tint: tier.style.color) {
                Label {
                    Text("Tier unlocked: \(tier.style.label)")
                        .font(.codeyHeadline)
                } icon: {
                    Image(systemName: tier.style.symbol)
                        .foregroundStyle(tier.style.color)
                }
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: CodeySpacing.sm) {
            if !wasEmpty {
                CodeyButton("Study Again", systemImage: "arrow.clockwise", kind: .glassSecondary, fullWidth: true, action: studyAgain)
                    .accessibilityIdentifier("study.again")
            }
            CodeyButton("Done", kind: .glassPrimary, fullWidth: true, action: done)
                .accessibilityIdentifier("study.done")
        }
        .padding(.top, CodeySpacing.sm)
    }

    private var emptyMessage: String {
        guard deck.origin == .starter else {
            return "This deck has no cards to study."
        }
        let level = (try? modelContext.fetch(FetchDescriptor<UserProfile>()).first)
        let locked = TierGate.availability(
            tallies: TierGate.tallies(for: deck),
            xp: level?.totalXP,
            level: level?.level ?? 1
        ).first { !$0.isUnlocked }
        if let locked, let reason = locked.lockReason {
            return "You've mastered every card you've unlocked. \(locked.difficulty.style.label) is next: \(reason)."
        }
        return "You've mastered every card in this deck. Mastered starter cards retire."
    }
}
