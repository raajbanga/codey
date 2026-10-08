import SwiftUI

/// One deck in the library grid.
struct DeckTile: View {
    let deck: FlashcardDeck
    let topic: Topic?

    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(alignment: .top) {
                IconTile(systemName: topic?.iconName ?? "rectangle.stack", size: iconSize, font: .codeyHeadline, radius: CodeyRadius.sm)
                Spacer(minLength: CodeySpacing.xs)
                DeckStatusChip(deck: deck)
            }

            Text(deck.title)
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(subtitle)
                .font(.codeyCaption)
                .foregroundStyle(CodeyColor.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            ProgressBar(value: deck.masteryRate, label: "Mastery \(deck.masteryRate.percentText)")
        }
        .padding(CodeySpacing.md)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(CodeyColor.surfaceRaised, in: .codey(CodeyRadius.lg))
        .opacity(deck.isHidden ? 0.6 : 1)
        .contentShape(.rect(cornerRadius: CodeyRadius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("deckTile.\(deck.title)")
    }

    private var subtitle: String {
        let cards = deck.cardCount.counted("card")
        return topic.map { "\(cards) · \($0.title)" } ?? cards
    }
}
