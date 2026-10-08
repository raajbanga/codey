import SwiftUI

/// Standard animations (D17). Use the modifiers below rather than raw
/// animations so Reduce Motion is respected everywhere.
enum CodeyMotion {
    static let snappy: Animation = .snappy(duration: 0.25)
    static let bouncy: Animation = .bouncy(duration: 0.4)
    static let smooth: Animation = .smooth(duration: 0.35)
    /// What any motion becomes under Reduce Motion: a short crossfade.
    static let reduced: Animation = .easeInOut(duration: 0.2)

    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : animation
    }

    /// Scale + fade normally; fade only under Reduce Motion.
    static func popTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity)
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
