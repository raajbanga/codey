import SwiftUI

struct FlashcardView: View {
    let question: Question

    @State private var isFlipped = false

    var body: some View {
        CodeyCard {
            VStack(spacing: CodeySpacing.md) {
                if isFlipped {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("Answer")
                            .font(.codeyCaption.weight(.semibold))
                            .foregroundStyle(CodeyColor.success)

                        Text(correctAnswerText)
                            .font(.codeyHeadline)

                        Divider()

                        Text(question.explanation)
                            .font(.codeySubheadline)
                            .foregroundStyle(CodeyColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                } else {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("Question")
                            .font(.codeyCaption.weight(.semibold))
                            .foregroundStyle(CodeyColor.brand)

                        Text(question.prompt)
                            .font(.codeyHeadline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Tap to reveal answer")
                            .font(.codeyCaption)
                            .foregroundStyle(CodeyColor.textSecondary)
                            .padding(.top, CodeySpacing.sm)
                    }
                }
            }
            .frame(minHeight: 220)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
        }
    }

    private var correctAnswerText: String {
        guard question.correctOptionIndex < question.options.count else {
            return "Unknown"
        }
        return question.options[question.correctOptionIndex]
    }
}

#Preview {
    FlashcardView(
        question: Question(
            id: "preview-q",
            prompt: "What is the average-case time complexity of a hash table lookup?",
            options: ["O(1)", "O(n)", "O(log n)", "O(n^2)"],
            correctOptionIndex: 0,
            explanation: "With a good hash function and low load factor, lookups are amortized O(1).",
            difficulty: .easy
        )
    )
    .padding()
}
