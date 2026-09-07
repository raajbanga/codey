import SwiftUI

enum QuizOptionState {
    case idle
    case selectedCorrect
    case selectedIncorrect
    case revealedCorrect
}

struct QuizOptionRow: View {
    let title: String
    let state: QuizOptionState
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard !isLocked else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, CodeySpacing.sm + 2)
                .padding(.horizontal, CodeySpacing.md)
                .foregroundStyle(foregroundColor)
                .background(backgroundColor)
                .overlay {
                    if state == .idle {
                        Capsule()
                            .stroke(ThemeColor.border, lineWidth: 1)
                    }
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLocked && state == .idle)
        .opacity(isLocked && state == .idle ? 0.6 : 1)
    }

    private var foregroundColor: Color {
        switch state {
        case .idle:
            return ThemeColor.primary
        case .selectedCorrect, .revealedCorrect:
            return .white
        case .selectedIncorrect:
            return .white
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .idle:
            return .clear
        case .selectedCorrect, .revealedCorrect:
            return ThemeColor.success
        case .selectedIncorrect:
            return ThemeColor.destructive
        }
    }
}

#Preview {
    VStack(spacing: CodeySpacing.sm) {
        QuizOptionRow(title: "O(1)", state: .idle, isLocked: false) {}
        QuizOptionRow(title: "O(n)", state: .selectedCorrect, isLocked: true) {}
        QuizOptionRow(title: "O(log n)", state: .selectedIncorrect, isLocked: true) {}
        QuizOptionRow(title: "O(n²)", state: .revealedCorrect, isLocked: true) {}
    }
    .padding()
}
