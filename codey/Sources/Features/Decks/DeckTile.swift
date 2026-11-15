import SwiftUI

/// One deck in the library's grid, laid out exactly like a Play topic
/// tile (S41; Nov 15): what studying pays top right, the title, then one
/// row of tags (card count, and an icon tag for sync state or hidden)
/// above the progress bar and the Study button the library lays over it.
struct DeckTile: View {
    let deck: FlashcardDeck
    let topic: Topic?
    /// Room for the library's Study button along the bottom.
    var reservesStudyButton = false

    var body: some View {
        GameTile(
            icon: topic?.iconName ?? "rectangle.stack",
            title: deck.title,
            hue: .of(topicID: deck.topicId),
            progress: deck.progressRate,
            reservesAction: reservesStudyButton
        ) {
            // What a card moved up pays (S41).
            if deck.cardCount > 0 { CodeyChip(xp: XPRewards.cardMovedUp) }
        } tags: {
            CodeyChip(deck.cardCount.counted("card"), systemImage: "rectangle.stack")
            if deck.isHidden {
                CodeyChip("", systemImage: "eye.slash").accessibilityLabel("Hidden")
            } else if deck.origin == .user {
                DeckStatusChip(deck: deck, compact: true)
            }
        }
        .opacity(deck.isHidden ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue("Progress \(deck.progressRate.percentText)")
        .accessibilityIdentifier("deckTile.\(deck.title)")
    }
}
