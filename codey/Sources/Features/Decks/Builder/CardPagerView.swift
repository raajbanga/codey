import SwiftUI

/// Horizontal pages of card editors, plus a final "+ New card" page (D15).
struct CardPagerView: View {
    let viewModel: DeckViewModel
    @Binding var page: PagerPage?
    @Binding var focusRequest: FocusRequest?
    /// Off while the keyboard is up, to give the card the room.
    var showsPosition = true
    /// Deletes with undo (DeckBuilderView's toast).
    let onDelete: (UUID) -> Void

    private var cards: [CardDraft] { viewModel.draft.cards }

    var body: some View {
        VStack(spacing: CodeySpacing.xs) {
            if showsPosition {
                Text(positionLabel)
                    .font(.codeyCaption.weight(.semibold))
                    .foregroundStyle(CodeyColor.textSecondary)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("pager.position")
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        CardPageEditor(
                            card: binding(for: card.id, at: index), viewModel: viewModel, focusRequest: $focusRequest,
                            duplicate: {
                                guard let id = viewModel.duplicateCard(cardID: card.id) else { return }
                                withAnimation(CodeyMotion.snappy) { page = .card(id) }
                            },
                            delete: { onDelete(card.id) }
                        )
                            .padding(.horizontal, CodeySpacing.md)
                            .containerRelativeFrame(.horizontal)
                            .id(PagerPage.card(card.id))
                    }
                    newCardPage
                        .padding(.horizontal, CodeySpacing.md)
                        .containerRelativeFrame(.horizontal)
                        .id(PagerPage.newCard)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
        }
    }

    private var positionLabel: String {
        switch page {
        case .card(let id):
            let index = (cards.firstIndex { $0.id == id } ?? 0) + 1
            return "Card \(index) of \(cards.count)"
        case .newCard:
            return "New card"
        case nil:
            return cards.isEmpty ? "No cards" : "Card 1 of \(cards.count)"
        }
    }

    private var newCardPage: some View {
        Button {
            let id = viewModel.addCard()
            withAnimation(CodeyMotion.snappy) { page = .card(id) }
        } label: {
            VStack(spacing: CodeySpacing.sm) {
                Icon("plus.circle.fill", size: 34, relativeTo: .largeTitle)
                Text("New card")
                    .font(.codeyHeadline)
            }
            .foregroundStyle(CodeyColor.brand)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CodeyColor.brandSoft, in: .codey(CodeyRadius.lg))
            .overlay {
                RoundedRectangle.codey(CodeyRadius.lg)
                    .strokeBorder(CodeyColor.brand, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .contentShape(.rect(cornerRadius: CodeyRadius.lg))
        }
        .buttonStyle(.plain)
        .padding(.vertical, CodeySpacing.xs)
        .accessibilityIdentifier("pager.newCard")
    }

    /// Reads and writes at the render's index once it's checked against the
    /// id, so a keystroke is O(1); after a delete shifts the cards, it falls
    /// back to a search instead of editing the wrong card.
    private func binding(for id: UUID, at hint: Int) -> Binding<CardDraft> {
        let viewModel = viewModel
        func index() -> Int? {
            let cards = viewModel.draft.cards
            return cards.indices.contains(hint) && cards[hint].id == id ? hint : cards.firstIndex { $0.id == id }
        }
        return Binding(
            get: { index().map { viewModel.draft.cards[$0] } ?? CardDraft(id: id) },
            set: { newValue in
                guard let index = index() else { return }
                viewModel.draft.cards[index] = newValue
            }
        )
    }
}
