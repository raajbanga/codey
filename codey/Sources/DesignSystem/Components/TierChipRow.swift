import SwiftUI

/// One tier's lock state for a topic or starter deck.
struct TierAvailability: Identifiable, Equatable {
    let difficulty: Difficulty
    let isUnlocked: Bool
    /// Shown when locked, e.g. "Retire 3 more Medium" or "Reach Level 3 · 420 XP to go".
    var lockReason: String?

    var id: Difficulty { difficulty }
}

/// Easy ✓ / Medium ✓ / Hard 🔒. Tapping a locked tier shows why it's locked.
struct TierChipRow: View {
    let tiers: [TierAvailability]

    var body: some View {
        HStack(spacing: CodeySpacing.xs) {
            ForEach(tiers) { tier in
                TierChip(tier: tier)
            }
        }
    }
}

/// "Tier unlocked: Medium" banner on the study and quiz summaries.
struct TierUnlockedBanner: View {
    let tier: Difficulty

    var body: some View {
        Label {
            Text("Tier unlocked: \(tier.style.label)")
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textPrimary)
        } icon: {
            Image(systemName: tier.style.symbol)
                .foregroundStyle(tier.style.color)
        }
        .padding(CodeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CodeyChipVariant.tier(tier).softColor, in: .codey(CodeyRadius.lg))
    }
}

private struct TierChip: View {
    let tier: TierAvailability
    @State private var showReason = false

    var body: some View {
        if tier.isUnlocked {
            CodeyChip(tier.difficulty.style.label, systemImage: tier.difficulty.style.symbol, variant: .tier(tier.difficulty))
                .accessibilityLabel("\(tier.difficulty.style.label) unlocked")
        } else {
            Button {
                showReason = true
            } label: {
                CodeyChip(tier.difficulty.style.label, systemImage: "lock.fill", variant: .neutral)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(tier.difficulty.style.label) locked")
            .accessibilityHint(tier.lockReason ?? "")
            .popover(isPresented: $showReason) {
                Text(tier.lockReason ?? "Keep practicing to unlock.")
                    .font(.codeyCallout)
                    .padding(CodeySpacing.md)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }
}
