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
        // Each reads every card of the deck: once per render, not per use.
        let count = deck.cardCount
        let progress = deck.progressRate
        return GameTile(
            icon: topic?.iconName ?? "rectangle.stack",
            title: deck.title,
            hue: .of(topicID: deck.topicId),
            progress: progress,
            reservesAction: reservesStudyButton
        ) {
            // What a card moved up pays (S41).
            if count > 0 { CodeyChip(xp: XPRewards.cardMovedUp) }
        } tags: {
            CodeyChip(count.counted("card"), systemImage: "rectangle.stack")
            if deck.isHidden {
                CodeyChip("", systemImage: "eye.slash").accessibilityLabel("Hidden")
            } else if deck.origin == .user {
                DeckStatusChip(deck: deck, compact: true)
            }
        }
        .opacity(deck.isHidden ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue("Progress \(progress.percentText)")
        .accessibilityIdentifier("deckTile.\(deck.title)")
    }
}

/// A deck tile that opens the deck, with a Study button laid over its
/// bottom (S40: study straight from the grid, continuing where you left
/// off). Decks and the Library's topic pages use it.
struct DeckTileLink: View {
    let deck: FlashcardDeck
    let topic: Topic?

    @Environment(Router.self) private var router

    var body: some View {
        let canStudy = !deck.isHidden && deck.hasActiveCards
        NavigationLink(value: DeckRoute(id: deck.id)) {
            DeckTile(deck: deck, topic: topic, reservesStudyButton: canStudy)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if canStudy {
                Button {
                    router.study = StudyRequest(deck: deck, start: .resume)
                } label: {
                    TileActionLabel(action: TileAction("Study"), hue: .of(topicID: deck.topicId))
                }
                .buttonStyle(TilePressStyle())
                .padding(CodeySpacing.md)
                .accessibilityLabel("Study \(deck.title)")
                .accessibilityIdentifier("deckTile.study.\(deck.title)")
            }
        }
    }
}
