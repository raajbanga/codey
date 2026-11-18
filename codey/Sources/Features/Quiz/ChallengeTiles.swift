import SwiftUI

/// Coding challenges (S45) on a Library topic page: one GameTile each,
/// with the tier and what a first solve pays, or Solved once done. Goes
/// inside a BentoSection, like the drills.
struct ChallengeTiles: View {
    let solved: Set<String>
    /// Only this topic's challenges; nil shows all.
    var topicID: String?

    private var shown: [Challenge] {
        ChallengeCatalog.shared.all.filter { topicID == nil || $0.topicId == topicID }
    }

    var body: some View {
        ForEach(shown) { challenge in
            let done = solved.contains(challenge.id)
            NavigationLink {
                ChallengeView(challenge: challenge)
            } label: {
                GameTile(
                    icon: done ? "checkmark.circle.fill" : "terminal",
                    title: challenge.title,
                    detail: challenge.difficulty.style.label,
                    hue: .of(topicID: challenge.topicId),
                    filled: false,
                    action: TileAction(
                        done ? "Again" : "Solve",
                        icon: done ? "arrow.counterclockwise" : "play",
                        prominent: !done
                    )
                ) {
                    if done {
                        CodeyChip("Solved", systemImage: "checkmark", variant: .success)
                    } else {
                        CodeyChip(xp: XPRewards.challengeReward(challenge.difficulty))
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityHint("Opens the challenge")
            }
            .buttonStyle(TilePressStyle())
            .accessibilityIdentifier("challenge.\(challenge.id)")
        }
    }
}
