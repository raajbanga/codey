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
    @Environment(\.codeyLayout) private var layout
    @State private var shown = false

    private static let duration: TimeInterval = 2.0

    var body: some View {
        ZStack {
            if shown {
                let symbol = layout.celebrationSymbol
                VStack(spacing: layout.isRegular ? CodeySpacing.md : CodeySpacing.sm) {
                    Icon(systemImage, size: symbol.size, relativeTo: .largeTitle)
                        .foregroundStyle(CodeyColor.brand)
                        .frame(width: symbol.circle, height: symbol.circle)
                        .background(CodeyColor.brandSoft, in: Circle())
                    Text(title)
                        .font(layout.isRegular ? .codeyDisplay : .codeyTitle)
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
