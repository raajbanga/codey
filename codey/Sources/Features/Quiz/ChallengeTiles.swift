import SwiftUI

/// A drill or coding challenge on a tile (S41, S45): Solve with what a first
/// solve pays, or Again with Solved once done. Opens `destination`. Goes
/// inside a BentoSection; ExerciseTiles and ChallengeTiles both use it.
struct SolvableTile<Destination: View>: View {
    let icon: String
    let title: String
    let detail: String
    let topicID: String
    let isSolved: Bool
    let xpReward: Int
    let accessibilityHint: String
    let identifier: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            // Same tile as a topic, on the plain note so the section reads
            // apart from the topics above (S41).
            GameTile(
                icon: isSolved ? "checkmark.circle.fill" : icon,
                title: title,
                detail: detail,
                hue: .of(topicID: topicID),
                filled: false,
                action: TileAction(
                    isSolved ? "Again" : "Solve",
                    icon: isSolved ? "arrow.counterclockwise" : "play",
                    prominent: !isSolved
                )
            ) {
                if isSolved {
                    CodeyChip("Solved", systemImage: "checkmark", variant: .success)
                } else {
                    CodeyChip(xp: xpReward)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(accessibilityHint)
        }
        .buttonStyle(TilePressStyle())
        .accessibilityIdentifier(identifier)
    }
}

/// Coding challenges (S45) on a Library topic page: one SolvableTile each,
/// with the tier and what a first solve pays.
struct ChallengeTiles: View {
    let solved: Set<String>
    /// Only this topic's challenges; nil shows all.
    var topicID: String?

    private var shown: [Challenge] {
        ChallengeCatalog.shared.all.filter { topicID == nil || $0.topicId == topicID }
    }

    var body: some View {
        ForEach(shown) { challenge in
            SolvableTile(
                icon: "terminal",
                title: challenge.title,
                detail: challenge.difficulty.style.label,
                topicID: challenge.topicId,
                isSolved: solved.contains(challenge.id),
                xpReward: challenge.xpReward,
                accessibilityHint: "Opens the challenge",
                identifier: "challenge.\(challenge.id)"
            ) {
                ChallengeView(challenge: challenge)
            }
        }
    }
}
