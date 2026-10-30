import SwiftUI

/// A quiet banner for level-ups, tier unlocks, and badges. Sprint 3 (S9)
/// replaced the particle burst: a symbol and a line of text fade in on a
/// flat card, a success haptic plays, VoiceOver announces it, and it fades
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
            if isPresented {
                VStack(spacing: CodeySpacing.sm) {
                    Image(systemName: systemImage)
                        .font(.largeTitle)
                        .foregroundStyle(CodeyColor.brand)
                        .frame(width: 64, height: 64)
                        .background(CodeyColor.brandSoft, in: Circle())
                    Text(title)
                        .font(.codeyTitle)
                        .foregroundStyle(CodeyColor.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, CodeySpacing.lg)
                .padding(.horizontal, CodeySpacing.xl)
                .background(CodeyColor.surfaceRaised, in: .codey(CodeyRadius.xl))
                .overlay {
                    RoundedRectangle.codey(CodeyRadius.xl)
                        .strokeBorder(CodeyColor.separator, lineWidth: 1)
                }
                .offset(y: shown || reduceMotion ? 0 : 8)
                .opacity(shown ? 1 : 0)
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
        shown = false
        withAnimation(CodeyMotion.resolve(CodeyMotion.smooth, reduceMotion: reduceMotion)) {
            shown = true
        }
        UIAccessibility.post(notification: .announcement, argument: title)
        Task {
            try? await Task.sleep(for: .seconds(Self.duration))
            withAnimation(CodeyMotion.reduced) { shown = false }
            try? await Task.sleep(for: .seconds(0.25))
            isPresented = false
        }
    }
}
