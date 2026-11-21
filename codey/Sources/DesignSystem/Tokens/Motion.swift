import SwiftUI

/// Standard animations. Sprint 3 (S9) keeps motion quiet: short snaps and
/// smooth settles only, no bounce. Use the modifiers below rather than raw
/// animations so Reduce Motion is respected everywhere.
enum CodeyMotion {
    static let snappy: Animation = .snappy(duration: 0.25)
    static let smooth: Animation = .smooth(duration: 0.35)
    /// Anything floating over the page appearing or leaving (S40): panels,
    /// celebrations, toasts. Paired with `popTransition`, it grows from 96%
    /// to full size in place, settling without bounce.
    static let pop: Animation = .spring(duration: 0.32, bounce: 0)
    /// What any motion becomes under Reduce Motion: a short crossfade.
    static let reduced: Animation = .easeInOut(duration: 0.2)

    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : animation
    }

    /// A slight scale + fade normally; fade only under Reduce Motion.
    static func popTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity)
    }
}

private struct CodeyAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(CodeyMotion.resolve(animation, reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    /// `.animation(_:value:)` that falls back to a crossfade under Reduce Motion.
    func codeyAnimation<V: Equatable>(_ animation: Animation = CodeyMotion.snappy, value: V) -> some View {
        modifier(CodeyAnimationModifier(animation: animation, value: value))
    }
}

/// `withAnimation` that respects Reduce Motion. Views pass in their
/// `@Environment(\.accessibilityReduceMotion)` value.
@discardableResult
func withCodeyAnimation<Result>(
    _ animation: Animation = CodeyMotion.snappy,
    reduceMotion: Bool,
    _ body: () throws -> Result
) rethrows -> Result {
    try withAnimation(CodeyMotion.resolve(animation, reduceMotion: reduceMotion), body)
}

/// Keeps `isUp` in step with the on-screen keyboard, animated (Reduce
/// Motion respected): the deck builder and a challenge shed their chrome
/// while typing (§3b).
private struct KeyboardTracker: ViewModifier {
    @Binding var isUp: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withCodeyAnimation(reduceMotion: reduceMotion) { isUp = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withCodeyAnimation(reduceMotion: reduceMotion) { isUp = false }
            }
    }
}

extension View {
    func trackKeyboard(_ isUp: Binding<Bool>) -> some View {
        modifier(KeyboardTracker(isUp: isUp))
    }
}
