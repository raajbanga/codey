import SwiftUI

/// A quiet banner for level-ups, tier unlocks, and badges. Sprint 3 (S9)
/// replaced the particle burst: a symbol and a line of text fade in on a
/// lifted card (popping in like every floating card, S40), a success haptic plays, VoiceOver announces it, and it fades
/// out on its own.
struct CelebrationOverlay: View {
    @Binding var isPresented: Bool
    let title: String
    var systemImage: String = "star.fill"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private static let duration: TimeInterval = 2.0

    var body: some View {
        ZStack {
            if shown {
                VStack(spacing: CodeySpacing.sm) {
                    Icon(systemImage, size: 32, relativeTo: .largeTitle)
                        .foregroundStyle(CodeyColor.brand)
                        .frame(width: 64, height: 64)
                        .background(CodeyColor.brandSoft, in: Circle())
                    Text(title)
                        .font(.codeyTitle)
                        .foregroundStyle(CodeyColor.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .codeyPanelPadding()
                // S40: the same lifted note and pop as FloatingPanel.
                .codeyFloatingCard()
                .padding(.horizontal, CodeySpacing.md)
                .transition(CodeyMotion.popTransition(reduceMotion: reduceMotion))
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .onChange(of: isPresented, initial: true) { _, presented in
            guard presented else { return }
            begin()
        }
        .sensoryFeedback(.success, trigger: isPresented) { _, new in new }
    }

    private func begin() {
        withCodeyAnimation(CodeyMotion.pop, reduceMotion: reduceMotion) { shown = true }
        UIAccessibility.post(notification: .announcement, argument: title)
        Task {
            try? await Task.sleep(for: .seconds(Self.duration))
            withCodeyAnimation(CodeyMotion.pop, reduceMotion: reduceMotion) { shown = false }
            try? await Task.sleep(for: .seconds(0.35))
            isPresented = false
        }
    }
}
