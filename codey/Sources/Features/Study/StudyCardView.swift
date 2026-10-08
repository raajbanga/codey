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
                .symbolEffect(.bounce, value: masteredBadge)
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
        return CardFace(card: card, isFront: isFront)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}

private struct CardFace: View {
    let card: Flashcard
    let isFront: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.md) {
            HStack(spacing: CodeySpacing.xs) {
                Text(isFront ? "Prompt" : "Answer")
                    .font(.codeyCaption.weight(.semibold))
                    .foregroundStyle(isFront ? CodeyColor.brand : CodeyColor.success)
                    .textCase(.uppercase)
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

            if isFront {
                Text("Tap to flip")
                    .font(.codeyCaption)
                    .foregroundStyle(CodeyColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .padding(CodeySpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .background(CodeyColor.surfaceRaised, in: .codey(CodeyRadius.lg))
        .containerShape(.rect(cornerRadius: CodeyRadius.lg, style: .continuous))
        .shadow(color: CodeyColor.textPrimary.opacity(0.08), radius: 12, y: 4)
    }

    @ViewBuilder
    private var content: some View {
        if isFront {
            CardMarkdownView(markdown: card.prompt, snippet: card.codeSnippet)
        } else {
            CardMarkdownView(markdown: card.answer)
        }
    }
}
