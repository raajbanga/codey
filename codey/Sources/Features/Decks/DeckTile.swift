import SwiftUI

/// One deck in the library's bento grid.
struct DeckTile: View {
    let deck: FlashcardDeck
    let topic: Topic?
    /// S40: room for the library's play button over the bottom-right corner.
    var reservesStudyButton = false

    var body: some View {
        BentoTile(icon: topic?.iconName ?? "rectangle.stack", title: deck.title, detail: subtitle, minHeight: 168) {
            DeckStatusChip(deck: deck)
        } footer: {
            ProgressBar(value: deck.progressRate, label: "Progress \(deck.progressRate.percentText)")
                .padding(.trailing, reservesStudyButton ? 44 + CodeySpacing.sm : 0)
        }
        .opacity(deck.isHidden ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("deckTile.\(deck.title)")
    }

    private var subtitle: String {
        let cards = deck.cardCount.counted("card")
        return topic.map { "\(cards), \($0.title)" } ?? cards
    }
}
