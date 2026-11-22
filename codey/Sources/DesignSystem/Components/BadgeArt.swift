import SwiftUI

/// A badge's picture (the trophy case, Nov 21): a pastel shape that says
/// what kind of badge it is, inner rings that say how hard it is, and a
/// line icon with an optional number in the shape's ink. Locked badges are
/// the shape alone in neutral grey (callers draw them smaller).
///
///     level ⬡   habit ✺ (stitched patch)   quiz ⬠
///     practice ◇   decks ▢   cards ⛉
///
/// Drawn on a 64 pt grid and scaled to fit, so the same art serves the
/// trophy case tile and the larger detail dialog. Decorative: the caller
/// carries the badge's name and state for VoiceOver.
struct BadgeArt: View {
    enum Family: Sendable {
        case level, habit, quiz, practice, decks, cards
    }

    struct Style {
        let family: Family
        let glyph: String
        let hue: CodeyColor.TopicHue
        var numeral: String?
        /// 1 to 3 inner rings (habit badges get a stitched ring instead).
        var rings = 1
    }

    let style: Style
    var isEarned = true

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                BadgeOutline(family: style.family)
                    .fill(isEarned ? style.hue.soft : CodeyColor.fillNeutral)
                if isEarned { detail(unit: side / 64) }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func detail(unit u: CGFloat) -> some View {
        let ink = style.hue.ink
        if style.family == .habit {
            Circle()
                .inset(by: 12 * u)
                .stroke(ink.opacity(0.45), style: StrokeStyle(lineWidth: 1.3 * u, lineCap: .round, dash: [2.2 * u, 2.6 * u]))
        } else {
            ForEach(1...max(style.rings, 1), id: \.self) { ring in
                BadgeOutline(family: style.family)
                    .scale(1 - 0.1 * CGFloat(ring))
                    .stroke(ink.opacity(0.28), lineWidth: 1.3 * u)
            }
        }
        let hasNumber = style.numeral != nil
        let glyph = (hasNumber ? 20 : 24) * u
        CodeyIcon.image(style.glyph)
            .resizable()
            .scaledToFit()
            .frame(width: glyph, height: glyph)
            .foregroundStyle(ink)
            .offset(y: hasNumber ? -5 * u : 0)
        if let numeral = style.numeral {
            // Part of the picture, so it scales with the art, not with
            // Dynamic Type (the tile's own label does).
            Text(numeral)
                .font(.system(size: 10.5 * u, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)
                .offset(y: 10.5 * u)
        }
    }
}

/// The outline of each badge family on the 64 pt grid, centered in `rect`.
struct BadgeOutline: Shape {
    let family: BadgeArt.Family

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 64
        let path: Path = switch family {
        case .level: Self.rounded([(32, 4.5), (55.8, 18.2), (55.8, 45.7), (32, 59.5), (8.2, 45.7), (8.2, 18.2)], radius: 4)
        case .quiz: Self.rounded([(32, 5), (58, 23.5), (48, 58), (16, 58), (6, 23.5)], radius: 4)
        case .practice: Self.rounded([(32, 5), (59, 32), (32, 59), (5, 32)], radius: 5)
        case .decks: Path(roundedRect: CGRect(x: 8, y: 6, width: 48, height: 52), cornerRadius: 6)
        case .cards: Self.shield
        case .habit: Self.rosette
        }
        return path
            .applying(CGAffineTransform(scaleX: scale, y: scale))
            .offsetBy(dx: rect.midX - 32 * scale, dy: rect.midY - 32 * scale)
    }

    /// A polygon with its corners rounded.
    private static func rounded(_ points: [(CGFloat, CGFloat)], radius: CGFloat) -> Path {
        let vertices = points.map { CGPoint(x: $0.0, y: $0.1) }
        var path = Path()
        guard let first = vertices.first, let last = vertices.last else { return path }
        path.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
        for (index, vertex) in vertices.enumerated() {
            path.addArc(tangent1End: vertex, tangent2End: vertices[(index + 1) % vertices.count], radius: radius)
        }
        path.closeSubpath()
        return path
    }

    private static let shield: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 32, y: 5))
        path.addCurve(to: CGPoint(x: 54, y: 11.4), control1: CGPoint(x: 40, y: 9.6), control2: CGPoint(x: 47.5, y: 11.4))
        path.addLine(to: CGPoint(x: 54, y: 30.2))
        path.addCurve(to: CGPoint(x: 32, y: 59), control1: CGPoint(x: 54, y: 44), control2: CGPoint(x: 45, y: 53.8))
        path.addCurve(to: CGPoint(x: 10, y: 30.2), control1: CGPoint(x: 19, y: 53.8), control2: CGPoint(x: 10, y: 44))
        path.addLine(to: CGPoint(x: 10, y: 11.4))
        path.addCurve(to: CGPoint(x: 32, y: 5), control1: CGPoint(x: 16.5, y: 11.4), control2: CGPoint(x: 24, y: 9.6))
        path.closeSubpath()
        return path
    }()

    /// A merit patch: a circle with 14 soft scallops.
    private static let rosette: Path = {
        var path = Path()
        let bumps = 14.0, steps = 14 * 12
        for step in 0...steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            let radius = 26.5 + 1.8 * cos(angle * bumps)
            let point = CGPoint(x: 32 + radius * sin(angle), y: 32 - radius * cos(angle))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }()
}

#Preview {
    let families: [(BadgeArt.Family, String, CodeyColor.TopicHue, String?)] = [
        (.level, "chevron.up.2", .sky, "5"), (.habit, "flame", .coral, "7"), (.quiz, "checkmark.bubble", .indigo, "50"),
        (.practice, "terminal", .sand, nil), (.decks, "checkmark.rectangle.stack", .violet, "5"),
        (.cards, "checkmark.rectangle.portrait", .green, "100"),
    ]
    VStack {
        HStack {
            ForEach(families.indices, id: \.self) { index in
                let (family, glyph, hue, numeral) = families[index]
                BadgeArt(style: .init(family: family, glyph: glyph, hue: hue, numeral: numeral, rings: index % 3 + 1))
            }
        }
        HStack {
            ForEach(families.indices, id: \.self) { index in
                BadgeArt(style: .init(family: families[index].0, glyph: "", hue: .slate), isEarned: false)
                    .padding(8)
            }
        }
    }
    .padding()
}
