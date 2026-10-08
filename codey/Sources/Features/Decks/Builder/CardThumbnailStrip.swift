import SwiftUI

/// Mini cards for jumping (tap), reordering (long-press drag), and
/// duplicate/delete (context menu). Red badge = errors after a failed save.
struct CardThumbnailStrip: View {
    let viewModel: DeckViewModel
    @Binding var page: PagerPage?
    let onDelete: (UUID) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: CodeySpacing.sm) {
                    ForEach(Array(viewModel.draft.cards.enumerated()), id: \.element.id) { index, card in
                        Thumbnail(
                            card: card,
                            number: index + 1,
                            isSelected: page == .card(card.id),
                            errorCount: viewModel.errorCount(cardID: card.id)
                        )
                        .id(PagerPage.card(card.id))
                        .onTapGesture {
                            withAnimation(CodeyMotion.snappy) { page = .card(card.id) }
                        }
                        .draggable(card.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            guard let raw = items.first, let dragged = UUID(uuidString: raw) else { return false }
                            withAnimation(CodeyMotion.snappy) { viewModel.moveCard(dragged, onto: card.id) }
                            return true
                        }
                        .contextMenu {
                            Button("Duplicate", systemImage: "plus.square.on.square") {
                                if let id = viewModel.duplicateCard(cardID: card.id) { page = .card(id) }
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) { onDelete(card.id) }
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction(named: "Duplicate") {
                            _ = viewModel.duplicateCard(cardID: card.id)
                        }
                        .accessibilityAction(named: "Delete") { onDelete(card.id) }
                    }

                    Button {
                        let id = viewModel.addCard()
                        withAnimation(CodeyMotion.snappy) { page = .card(id) }
                    } label: {
                        Image(systemName: "plus")
                            .font(.codeyHeadline)
                            .frame(width: 56, height: 72)
                            .background(CodeyColor.brandSoft, in: .codey(CodeyRadius.sm))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CodeyColor.brand)
                    .accessibilityLabel("Add card")
                    .accessibilityIdentifier("strip.addCard")
                }
                .padding(.horizontal, CodeySpacing.md)
                .padding(.vertical, CodeySpacing.xs)
            }
            .scrollIndicators(.hidden)
            .onChange(of: page) { _, newPage in
                guard let newPage else { return }
                withAnimation(CodeyMotion.snappy) { proxy.scrollTo(newPage, anchor: .center) }
            }
        }
    }
}

private struct Thumbnail: View {
    let card: CardDraft
    let number: Int
    let isSelected: Bool
    let errorCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
            Text(card.summary.isEmpty ? "Empty" : card.summary)
                .font(.codeyCaption)
                .foregroundStyle(card.summary.isEmpty ? CodeyColor.textSecondary : CodeyColor.textPrimary)
                .lineLimit(3)
            Spacer(minLength: 0)
            HStack(spacing: CodeySpacing.xxs) {
                Text("\(number)")
                    .font(.codeyCaption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(CodeyColor.textSecondary)
                if card.snippet != nil {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.codeyCaption)
                        .foregroundStyle(CodeyColor.brand)
                }
            }
        }
        .padding(CodeySpacing.xs + CodeySpacing.xxs)
        .frame(width: 56, height: 72, alignment: .topLeading)
        .background(CodeyColor.surfaceRaised, in: .codey(CodeyRadius.sm))
        .overlay {
            RoundedRectangle.codey(CodeyRadius.sm)
                .strokeBorder(isSelected ? CodeyColor.brand : CodeyColor.separator, lineWidth: isSelected ? 2 : 1)
        }
        .overlay(alignment: .topTrailing) {
            if errorCount > 0 {
                // A dot, not a number: white text on dark-mode danger fails
                // 4.5:1. The count is in the accessibility value.
                Circle()
                    .fill(CodeyColor.danger)
                    .frame(width: 12, height: 12)
                    .overlay { Circle().strokeBorder(CodeyColor.surfaceRaised, lineWidth: 2) }
                    .offset(x: 4, y: -4)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Card \(number): \(card.summary.isEmpty ? "empty" : card.summary)")
        .accessibilityValue(errorCount > 0 ? "\(errorCount) errors" : (isSelected ? "Selected" : ""))
    }
}
