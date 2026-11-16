import SwiftUI

/// Two faces that flip like a card (B15), shared by the study card and the
/// deck builder. Each face rotates on its own: the front turns 0→90°, then
/// the back turns −90→0°, so neither is ever mirrored and text stays
/// readable. Both get the taller face's height, so the card doesn't resize
/// as it turns. Under Reduce Motion the faces crossfade.
struct FlipCard<Front: View, Back: View>: View {
    let isFlipped: Bool
    @ViewBuilder var front: Front
    @ViewBuilder var back: Back

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static var halfFlip: Double { 0.18 }

    var body: some View {
        MatchedFaces {
            turning(front, shown: !isFlipped, awayAngle: 90)
            turning(back, shown: isFlipped, awayAngle: -90)
        }
    }

    private func turning(_ face: some View, shown: Bool, awayAngle: Double) -> some View {
        face
            .rotation3DEffect(.degrees(reduceMotion || shown ? 0 : awayAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .opacity(shown ? 1 : 0)
            // The face going away turns first (ease-in); the one coming in
            // turns after it (ease-out, delayed).
            .animation(
                reduceMotion ? CodeyMotion.reduced
                    : shown ? .easeOut(duration: Self.halfFlip).delay(Self.halfFlip) : .easeIn(duration: Self.halfFlip),
                value: isFlipped
            )
            .allowsHitTesting(shown)
            .accessibilityHidden(!shown)
    }
}

/// Stacks the faces at the taller one's height for the width offered,
/// measured on every layout pass.
private struct MatchedFaces: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(proposal) }
        return CGSize(width: proposal.width ?? sizes.map(\.width).max() ?? 0, height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for face in subviews {
            face.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}
