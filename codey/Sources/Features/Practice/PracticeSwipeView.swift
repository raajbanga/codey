import SwiftUI

struct PracticeSwipeView: View {
    @Environment(\.dismiss) private var dismiss

    let topic: Topic

    @State private var deck: [Question] = []
    @State private var dragOffset: CGSize = .zero
    @State private var isFinished = false

    var body: some View {
        Group {
            if isFinished {
                finishedView
            } else if deck.isEmpty {
                ProgressView()
            } else {
                cardStack
            }
        }
        .background(CodeyColor.surface)
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if deck.isEmpty { deck = topic.questions.shuffled() }
        }
    }

    private var cardStack: some View {
        VStack(spacing: CodeySpacing.md) {
            HStack {
                CodeyChip("\(deck.count) cards left", variant: .neutral)
                Spacer()
                CodeyChip(topic.title, variant: .success)
            }
            .padding(.horizontal, CodeySpacing.md)

            Spacer()

            ZStack {
                if deck.count > 1 {
                    FlashcardView(question: deck[1])
                        .scaleEffect(0.95)
                        .opacity(0.6)
                        .padding(.horizontal, CodeySpacing.md)
                }

                FlashcardView(question: deck[0])
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                    .gesture(
                        DragGesture()
                            .onChanged { dragOffset = $0.translation }
                            .onEnded { value in
                                if abs(value.translation.width) > 100 {
                                    dismissTopCard(direction: value.translation.width)
                                } else {
                                    withAnimation(.spring()) { dragOffset = .zero }
                                }
                            }
                    )
                    .padding(.horizontal, CodeySpacing.md)
            }

            Text("Swipe left or right to continue")
                .font(.codeyCaption)
                .foregroundStyle(CodeyColor.textSecondary)

            Spacer()
        }
    }

    private var finishedView: some View {
        ScrollView {
            VStack(spacing: CodeySpacing.md) {
                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("All Done!")
                            .font(.codeyHeadline)
                        Text("You've reviewed all \(topic.questions.count) cards in \(topic.title).")
                            .font(.codeySubheadline)
                            .foregroundStyle(CodeyColor.textSecondary)
                    }
                }
                CodeyButton("Back to Topics", fullWidth: true) { dismiss() }
            }
            .padding(CodeySpacing.md)
        }
    }

    private func dismissTopCard(direction: CGFloat) {
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = CGSize(width: direction > 0 ? 500 : -500, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            deck.removeFirst()
            dragOffset = .zero
            if deck.isEmpty { isFinished = true }
        }
    }
}
