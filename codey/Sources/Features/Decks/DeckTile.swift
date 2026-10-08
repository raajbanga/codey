import SwiftUI

/// One deck in the library grid.
struct DeckTile: View {
    let deck: FlashcardDeck
    let topic: Topic?

    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(alignment: .top) {
                Image(systemName: topic?.iconName ?? "rectangle.stack")
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.brand)
                    .frame(width: iconSize, height: iconSize)
                    .background(CodeyColor.brandSoft, in: .codey(CodeyRadius.sm))
                    .accessibilityHidden(true)
                Spacer(minLength: CodeySpacing.xs)
                if deck.origin == .starter {
                    CodeyChip("Starter", systemImage: "sparkles", variant: .brand)
                } else {
                    SyncStatusLabel(state: deck.syncState)
                }
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

            ProgressBar(value: deck.masteryRate, label: "Mastery \(Int((deck.masteryRate * 100).rounded()))%")
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
        let count = deck.cardCount
        let cards = count == 1 ? "1 card" : "\(count) cards"
        guard let topic else { return cards }
        return "\(cards) · \(topic.title)"
    }
}
