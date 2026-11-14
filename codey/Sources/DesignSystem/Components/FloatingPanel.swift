import SwiftUI

/// A note lifted off the page (S40): a dotted-paper card centered over a
/// dimmed screen, with a margin on every side. Used for quiz setup and the
/// Ask AI chat.
///
///     ░░░░░░░░░░░░░░░░░░░░░░   ← the screen, dimmed (tap to close)
///     ░ ╭─────────────────╮ ░
///     ░ │ panel content   │ ░  ← centered; drag down to close
///     ░ ╰─────────────────╯ ░
///     ░░░░░░░░░░░░░░░░░░░░░░
///
/// It pops in from the center (`CodeyMotion.pop`: a slight scale and fade,
/// shared with every floating card in the app) and closes by dragging down,
/// a tap on the dimmed screen, the content's own close button
/// (`\.dismissPanel`), or the VoiceOver escape gesture. Short content sizes
/// to fit (scrolling only when it must); `fillsHeight` panels (a chat) take
/// most of the screen.
private struct FloatingPanelModifier<Item: Identifiable, Panel: View>: ViewModifier {
    @Binding var item: Item?
    let fillsHeight: Bool
    let panel: (Item) -> Panel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0

    /// Past this (or a fast flick) a drag closes the panel.
    private let dismissDistance: CGFloat = 120

    func body(content: Content) -> some View {
        // No accessibilityHidden on `content`: `.accessibilityHidden(false)`
        // re-exposed the hidden paper background as an undescribed
        // full-screen image (audit). The card's `.isModal` already keeps
        // VoiceOver inside the panel.
        content
            .overlay {
                ZStack {
                    if item != nil {
                        scrim.transition(.opacity)
                    }
                    if let item {
                        card(item)
                            .transition(CodeyMotion.popTransition(reduceMotion: reduceMotion))
                    }
                }
                .animation(CodeyMotion.resolve(CodeyMotion.pop, reduceMotion: reduceMotion), value: item?.id)
            }
    }

    private var scrim: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .contentShape(.rect)
            .onTapGesture(perform: close)
            .accessibilityHidden(true)
    }

    private func card(_ item: Item) -> some View {
        Group {
            if fillsHeight {
                panel(item).frame(maxHeight: .infinity)
            } else {
                // Fits when it can; scrolls at large Dynamic Type sizes.
                ViewThatFits(in: .vertical) {
                    panel(item)
                    ScrollView { panel(item) }
                }
            }
        }
        .codeyFloatingCard()
        .padding(.horizontal, CodeySpacing.md)
        .padding(.vertical, fillsHeight ? CodeySpacing.xl : CodeySpacing.xxl)
        // Follows a downward drag, eased so it reads as "let go to close".
        .offset(y: max(dragOffset, 0) * 0.6)
        .scaleEffect(1 - min(max(dragOffset, 0) / 2000, 0.05))
        .gesture(drag)
        .environment(\.dismissPanel, DismissPanelAction(close))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { dragOffset = $0.translation.height }
            .onEnded { value in
                if value.translation.height > dismissDistance || value.predictedEndTranslation.height > dismissDistance * 2.5 {
                    close()
                }
                withAnimation(CodeyMotion.resolve(CodeyMotion.pop, reduceMotion: reduceMotion)) { dragOffset = 0 }
            }
    }

    private func close() {
        item = nil
    }
}

/// Closes the floating panel the view is in (no-op outside one).
struct DismissPanelAction {
    private let action: () -> Void

    init(_ action: @escaping () -> Void = {}) { self.action = action }

    func callAsFunction() { action() }
}

extension EnvironmentValues {
    @Entry var dismissPanel = DismissPanelAction()
}

extension View {
    /// Presents `panel` as a centered FloatingPanel while `item` is non-nil.
    func floatingPanel<Item: Identifiable, Panel: View>(
        item: Binding<Item?>,
        fillsHeight: Bool = false,
        @ViewBuilder panel: @escaping (Item) -> Panel
    ) -> some View {
        modifier(FloatingPanelModifier(item: item, fillsHeight: fillsHeight, panel: panel))
    }
}
