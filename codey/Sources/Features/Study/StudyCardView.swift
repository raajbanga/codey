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

    var body: some View {
        ZStack {
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
        return CardFace(card: card, isFront: isFront, scoreChange: scoreChange, isRepeat: isRepeat)
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
                    .scrollIndicators(.visible)
            }

            Spacer(minLength: 0)
            MasteryDots(
                score: scoreChange?.new ?? card.masteryScore,
                previousScore: scoreChange?.previous
            )
        }
        .padding(CodeySpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
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
