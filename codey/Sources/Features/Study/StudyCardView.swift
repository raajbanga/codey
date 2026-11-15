import SwiftUI

/// The study card (B15 rebuild). Two separate faces in a ZStack, each
/// rotating on its own: the front turns 0→90°, then the back turns −90→0°.
/// Neither face is ever mirrored, so text stays readable and selectable.
/// Under Reduce Motion the faces crossfade instead.
struct StudyCardView: View {
    let card: Flashcard
    let isRevealed: Bool
    /// "Mastered" chip popped by the rating that just mastered this card.
    var masteredBadge: MasteredBadge?
    /// The rating being applied: the dots show the new score and the change
    /// for a moment before the next card (S19).
    var scoreChange: ScoreChange?
    /// This card came back after "Again" (S19).
    var isRepeat = false

    struct ScoreChange: Equatable {
        let previous: Int
        let new: Int
    }

    enum MasteredBadge: Equatable {
        case mastered
        case masteredAndRetired
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let halfFlip = 0.18
    /// Shortest card, so a one-line prompt still reads as a card.
    static let minHeight: CGFloat = 260

    var body: some View {
        // Sized to its text (at least `minHeight`); a card too tall for the
        // screen fills it and scrolls inside instead.
        ViewThatFits(in: .vertical) {
            faces.fixedSize(horizontal: false, vertical: true)
            faces
        }
        .overlay(alignment: .top) {
            if let masteredBadge {
                CodeyChip(
                    masteredBadge == .masteredAndRetired ? "Mastered · retired" : "Mastered",
                    systemImage: "checkmark.seal.fill",
                    variant: .success
                )
                .padding(.top, CodeySpacing.sm)
                .transition(CodeyMotion.popTransition(reduceMotion: reduceMotion))
            }
        }
    }

    /// Both faces at the taller one's height (MatchedFaces), so the card
    /// doesn't change size as it flips.
    private var faces: some View {
        MatchedFaces {
            face(isFront: true)
                .rotation3DEffect(
                    .degrees(reduceMotion ? 0 : (isRevealed ? 90 : 0)),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .opacity(isRevealed ? 0 : 1)
                .animation(faceAnimation(showing: !isRevealed), value: isRevealed)
            face(isFront: false)
                .rotation3DEffect(
                    .degrees(reduceMotion ? 0 : (isRevealed ? 0 : -90)),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .opacity(isRevealed ? 1 : 0)
                .animation(faceAnimation(showing: isRevealed), value: isRevealed)
        }
    }

    /// The face being hidden turns away first (ease-in); the face being shown
    /// turns in after it (ease-out, delayed). Reduce Motion: a crossfade.
    private func faceAnimation(showing: Bool) -> Animation {
        if reduceMotion { return CodeyMotion.reduced }
        return showing
            ? .easeOut(duration: Self.halfFlip).delay(Self.halfFlip)
            : .easeIn(duration: Self.halfFlip)
    }

    private func face(isFront: Bool) -> some View {
        let visible = isFront != isRevealed
        return CardFace(
            card: card, isFront: isFront, scoreChange: scoreChange, isRepeat: isRepeat
        )
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}

private struct CardFace: View {
    let card: Flashcard
    let isFront: Bool
    let scoreChange: StudyCardView.ScoreChange?
    let isRepeat: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.md) {
            HStack(spacing: CodeySpacing.xs) {
                Text(isFront ? "Prompt" : "Answer")
                    .font(.codeySubheadline.weight(.medium))
                    .foregroundStyle(isFront ? CodeyColor.brand : CodeyColor.success)
                if isRepeat {
                    CodeyChip("Repeat", systemImage: "arrow.counterclockwise")
                }
                Spacer()
                if let difficulty = card.difficulty {
                    CodeyChip(tier: difficulty)
                }
            }

            // Fits the content up to the space available, then scrolls
            // inside the card (long code).
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
                    .scrollBounceBehavior(.basedOnSize)
            }

            Spacer(minLength: 0)
            MasteryDots(
                score: scoreChange?.new ?? card.masteryScore,
                previousScore: scoreChange?.previous
            )
        }
        .padding(CodeySpacing.lg)
        .frame(maxWidth: .infinity, minHeight: StudyCardView.minHeight, alignment: .topLeading)
        .codeyNote()
        .containerShape(.rect(cornerRadius: CodeyRadius.lg, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if isFront {
            CardMarkdownView(markdown: card.prompt, snippet: card.codeSnippet, font: .codeyCardText, isSelectable: false)
        } else {
            CardMarkdownView(markdown: card.answer, font: .codeyCardText, isSelectable: false)
        }
    }
}

/// Stacks the two faces and gives both the taller face's height for the
/// width offered. It measures on every layout, so a card is never stuck at
/// a height from an earlier pass (the old `faceHeight` only ever grew, and
/// one tall pass left a short card huge).
private struct MatchedFaces: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(proposal) }
        return CGSize(
            width: proposal.width ?? sizes.map(\.width).max() ?? 0,
            height: sizes.map(\.height).max() ?? 0
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for face in subviews {
            face.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}
