import SwiftUI

/// The study card (B15 rebuild): the prompt and answer faces on a shared
/// FlipCard.
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

    private var faces: some View {
        FlipCard(isFlipped: isRevealed) {
            CardFace(card: card, isFront: true, scoreChange: scoreChange, isRepeat: isRepeat)
        } back: {
            CardFace(card: card, isFront: false, scoreChange: scoreChange, isRepeat: isRepeat)
        }
    }
}

private struct CardFace: View {
    let card: Flashcard
    let isFront: Bool
    let scoreChange: StudyCardView.ScoreChange?
    let isRepeat: Bool
    @Environment(\.codeyLayout) private var layout

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
        .frame(maxWidth: .infinity, minHeight: layout.flashcard.minHeight, alignment: .topLeading)
        .codeyNote()
        .containerShape(.rect(cornerRadius: CodeyRadius.lg, style: .continuous))
        // iPad: an index card, not a full-width banner, centred.
        .frame(maxWidth: layout.flashcard.maxWidth)
        .frame(maxWidth: .infinity)
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
