import SwiftUI

/// A note lifted off the page (S40): a dotted-paper card centered over a
/// dimmed screen, with a margin on every side. Used for quiz setup and the
/// Ask AI chat.
///
///     ░░░░░░░░░░░░░░░░░░░░░░   ← the screen, dimmed (tap to close)
///     ░ ╭─────────────────╮ ░
///     ░ │ panel content   │ ░  ← centered; swipe any way to close
///     ░ ╰─────────────────╯ ░
///     ░░░░░░░░░░░░░░░░░░░░░░
///
/// It pops in from the center (`CodeyMotion.pop`: a slight scale and fade,
/// shared with every floating card in the app) and closes by a swipe in
/// any direction, a tap on the dimmed screen, the content's own close
/// button if it has one (`\.dismissPanel`), or the VoiceOver escape
/// gesture. Short content sizes
/// to fit (scrolling only when it must); `fillsHeight` panels (a chat) take
/// most of the screen.
private struct FloatingPanelModifier<Item: Identifiable, Panel: View>: ViewModifier {
    @Binding var item: Item?
    let fillsHeight: Bool
    let panel: (Item) -> Panel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        .modifier(SwipeToClose(close: close))
        .environment(\.dismissPanel, DismissPanelAction(close))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
    }

    private func close() {
        item = nil
    }
}

/// Swipe away like a flashcard (Nov 15): follows the finger with the same
/// tilt, flies off the way it was thrown, then closes. The offset lives
/// here, so a drag frame only moves the panel, not its content.
private struct SwipeToClose: ViewModifier {
    let close: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset = CGSize.zero

    func body(content: Content) -> some View {
        content
            .swipeFollow(offset, tilts: !reduceMotion)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { offset = $0.translation }
                    .onEnded { value in
                        guard SwipeMotion.isThrown(value.translation) else {
                            withCodeyAnimation(CodeyMotion.smooth, reduceMotion: reduceMotion) { offset = .zero }
                            return
                        }
                        guard !reduceMotion else { return close() }
                        Task { @MainActor in
                            await SwipeMotion.flyOff(along: value.translation) { offset = $0 }
                            close()
                        }
                    }
            )
    }
}

/// How a swiped card moves, shared by flashcards and floating panels: it
/// follows the finger with a slight tilt; past `threshold` it flies off
/// the way it was thrown, otherwise it springs back.
enum SwipeMotion {
    static let threshold: CGFloat = 110
    static let flyOffDuration = Duration.milliseconds(220)

    static func isThrown(_ translation: CGSize) -> Bool {
        hypot(translation.width, translation.height) > threshold
    }

    /// Animates `set` from where the finger let go to off screen, along the
    /// swipe, and returns once it's gone.
    @MainActor
    static func flyOff(along translation: CGSize, _ set: (CGSize) -> Void) async {
        let scale = 1000 / max(hypot(translation.width, translation.height), 1)
        withAnimation(.easeOut(duration: 0.22)) { set(CGSize(width: translation.width * scale, height: translation.height * scale)) }
        try? await Task.sleep(for: flyOffDuration)
    }
}

extension View {
    /// Moves and tilts a card with the drag (see `SwipeMotion`).
    func swipeFollow(_ drag: CGSize, tilts: Bool) -> some View {
        offset(drag).rotationEffect(.degrees(tilts ? Double(drag.width / 20) : 0))
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
