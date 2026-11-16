import SwiftUI

/// One tier's lock state for a topic or starter deck.
struct TierAvailability: Identifiable, Equatable {
    let difficulty: Difficulty
    let isUnlocked: Bool
    /// Shown when locked, e.g. "Retire 3 more Medium" or "Reach Level 3 · 420 XP to go".
    var lockReason: String?

    var id: Difficulty { difficulty }
}

/// The next locked tier and what opens it, one line under a tier picker
/// (quiz setup, a starter deck's Study block; Nov 15). Replaces the row of
/// tier tags that repeated the picker's own choices.
struct TierLockNote: View {
    let tiers: [TierAvailability]

    var body: some View {
        if let locked = tiers.first(where: { !$0.isUnlocked }), let reason = locked.lockReason {
            Label("\(locked.difficulty.style.label) unlocks: \(reason)", systemImage: "lock")
                .font(.codeySubheadline)
                .foregroundStyle(CodeyColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("tier.locked")
        }
    }
}

/// "Tier unlocked: Medium" banner on the study and quiz summaries.
struct TierUnlockedBanner: View {
    let tier: Difficulty

    // Same note + colored edge as the level-up banner it sits under.
    var body: some View {
        CodeyCard(tint: tier.style.color) {
            Label {
                Text("Tier unlocked: \(tier.style.label)")
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
            } icon: {
                Icon(tier.style.symbol, relativeTo: .headline)
                    .foregroundStyle(tier.style.color)
            }
        }
    }
}

