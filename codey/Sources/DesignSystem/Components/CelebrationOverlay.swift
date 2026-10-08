import SwiftUI

/// Particle burst for level-ups and tier unlocks ONLY (D17). No assets:
/// TimelineView + Canvas. Under Reduce Motion it's just a badge that fades.
struct CelebrationOverlay: View {
    @Binding var isPresented: Bool
    let title: String
    var systemImage: String = "star.fill"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var particles: [Particle] = []
    @State private var badgeShown = false

    private static let duration: TimeInterval = 1.8

    var body: some View {
        ZStack {
            if isPresented {
                if !reduceMotion {
                    TimelineView(.animation) { context in
                        Canvas { canvas, size in
                            draw(in: &canvas, size: size, elapsed: context.date.timeIntervalSince(start))
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                VStack(spacing: CodeySpacing.sm) {
                    Image(systemName: systemImage)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(CodeyColor.brand)
                        .symbolEffect(.bounce, value: badgeShown)
                    Text(title)
                        .font(.codeyTitle)
                        .foregroundStyle(CodeyColor.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(CodeySpacing.lg)
                .glassEffect(.regular, in: .rect(cornerRadius: CodeyRadius.xl, style: .continuous))
                .scaleEffect(badgeShown || reduceMotion ? 1 : 0.6)
                .opacity(badgeShown ? 1 : 0)
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
        start = .now
        particles = (0..<60).map { _ in Particle.random() }
        badgeShown = false
        withAnimation(CodeyMotion.resolve(CodeyMotion.bouncy, reduceMotion: reduceMotion)) {
            badgeShown = true
        }
        UIAccessibility.post(notification: .announcement, argument: title)
        Task {
            try? await Task.sleep(for: .seconds(Self.duration + 0.4))
            withAnimation(CodeyMotion.reduced) { badgeShown = false }
            try? await Task.sleep(for: .seconds(0.25))
            isPresented = false
        }
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        guard elapsed < Self.duration else { return }
        let t = elapsed
        let origin = CGPoint(x: size.width / 2, y: size.height * 0.42)
        let gravity: Double = 900
        for particle in particles {
            let x = origin.x + particle.velocity.dx * t
            let y = origin.y + particle.velocity.dy * t + 0.5 * gravity * t * t
            let alpha = max(0, 1 - t / Self.duration)
            var shape = canvas
            shape.opacity = alpha
            shape.translateBy(x: x, y: y)
            shape.rotate(by: .radians(particle.spin * t))
            let rect = CGRect(x: -particle.size / 2, y: -particle.size / 4, width: particle.size, height: particle.size / 2)
            shape.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(particle.color))
        }
    }

    private struct Particle {
        let velocity: CGVector
        let size: CGFloat
        let spin: Double
        let color: Color

        static let palette: [Color] = [
            CodeyColor.brand, CodeyColor.Tier.easy, CodeyColor.Tier.medium, CodeyColor.Tier.hard, CodeyColor.success,
        ]

        static func random() -> Particle {
            let angle = Double.random(in: -Double.pi * 0.95 ... -Double.pi * 0.05)
            let speed = Double.random(in: 280...620)
            return Particle(
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                size: .random(in: 6...11),
                spin: .random(in: -8...8),
                color: palette.randomElement() ?? CodeyColor.brand
            )
        }
    }
}
