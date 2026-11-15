import SwiftUI

/// One deck in the library's grid: the same GameTile as a Play topic (S41),
/// with the card count, progress, and room for the Study button the library
/// lays over the bottom.
struct DeckTile: View {
    let deck: FlashcardDeck
    let topic: Topic?
    /// Room for the library's Study button along the bottom.
    var reservesStudyButton = false

    var body: some View {
        GameTile(
            icon: topic?.iconName ?? "rectangle.stack",
            title: deck.title,
            detail: deck.cardCount.counted("card"),
            hue: .of(topicID: deck.topicId),
            progress: deck.progressRate,
            reservesAction: reservesStudyButton
        ) {
            // Starter is the default; only a user deck's sync state or a
            // hidden deck is worth a chip.
            if deck.origin == .user || deck.isHidden {
                DeckStatusChip(deck: deck)
            }
        } tags: {
            // What a card moved up pays (S41).
            if deck.cardCount > 0 { CodeyChip(xp: XPRewards.cardMovedUp) }
        }
        .opacity(deck.isHidden ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue("Progress \(deck.progressRate.percentText)")
        .accessibilityIdentifier("deckTile.\(deck.title)")
    }
}
