import SwiftUI

/// Horizontal pages of card editors, plus a final "+ New card" page (D15).
struct CardPagerView: View {
    let viewModel: DeckViewModel
    @Binding var page: PagerPage?
    @Binding var focusRequest: FocusRequest?

    private var cards: [CardDraft] { viewModel.draft.cards }

    var body: some View {
        VStack(spacing: CodeySpacing.xs) {
            Text(positionLabel)
                .font(.codeyCaption.weight(.semibold))
                .foregroundStyle(CodeyColor.textSecondary)
                .contentTransition(.numericText())
                .accessibilityIdentifier("pager.position")

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        CardPageEditor(card: binding(for: card.id), number: index + 1, viewModel: viewModel, focusRequest: $focusRequest)
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
                Image(systemName: "plus.circle.fill")
                    .font(.codeyDisplay)
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

    /// Looks cards up by id, so deleting one can't leave a stale index binding.
    private func binding(for id: UUID) -> Binding<CardDraft> {
        Binding(
            get: { viewModel.draft.cards.first { $0.id == id } ?? CardDraft(id: id) },
            set: { newValue in
                guard let index = viewModel.draft.cards.firstIndex(where: { $0.id == id }) else { return }
                viewModel.draft.cards[index] = newValue
            }
        )
    }
}
