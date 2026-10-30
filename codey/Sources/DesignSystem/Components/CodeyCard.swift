import SwiftUI

/// Content card: a rounded note on the dotted paper (`.codeyNote`). An
/// optional tint replaces the hairline with a 1pt colored outline to mark
/// the card that needs attention. Children can use ConcentricRectangle /
/// .containerShape-relative shapes to nest with matching corners.
struct CodeyCard<Content: View>: View {
    var tint: Color?
    @ViewBuilder let content: Content

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(CodeySpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .codeyNote(edge: tint)
            .containerShape(.rect(cornerRadius: CodeyRadius.lg, style: .continuous))
    }
}

extension View {
    /// A rounded note lying on the paper: a raised (or tinted) fill, a
    /// hairline edge, and a barely-there lift. Used by CodeyCard, Home's
    /// topic notes, and the Up-next note.
    func codeyNote(fill: Color = CodeyColor.surfaceRaised, edge: Color? = nil) -> some View {
        background {
            RoundedRectangle.codey(CodeyRadius.lg)
                .fill(fill)
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
        .overlay {
            RoundedRectangle.codey(CodeyRadius.lg)
                .strokeBorder(edge ?? CodeyColor.separator, lineWidth: 1)
        }
    }

    /// A flat raised surface with a hairline outline, for toasts and other
    /// small things floating over content (replaces custom glass, S9).
    func codeyFloatingSurface(in shape: some InsettableShape = RoundedRectangle.codey(CodeyRadius.xl)) -> some View {
        background(CodeyColor.surfaceRaised, in: shape)
            .overlay { shape.strokeBorder(CodeyColor.separator, lineWidth: 1) }
    }

    /// The app's page background: warm paper with a faint dot grid.
    func codeyPaperBackground() -> some View {
        background { PaperBackground().ignoresSafeArea() }
    }

    /// Puts a List on the dotted paper. Rows keep the system grouped row
    /// color, which matches SurfaceRaised closely in both modes.
    func codeyListBackground() -> some View {
        scrollContentBackground(.hidden)
            .codeyPaperBackground()
    }
}

/// Warm paper with a faint dot grid, like a notebook page. The dots stay
/// put while content scrolls over them. Increase Contrast drops the dots so
/// only content carries contrast.
struct PaperBackground: View {
    @Environment(\.colorSchemeContrast) private var contrast

    private static let pitch: CGFloat = 20
    private static let dot: CGFloat = 1.6

    var body: some View {
        CodeyColor.surface
            .overlay {
                if contrast == .standard {
                    Canvas { context, size in
                        let dots = Path { path in
                            var y = Self.pitch / 2
                            while y < size.height {
                                var x = Self.pitch / 2
                                while x < size.width {
                                    path.addEllipse(in: CGRect(
                                        x: x - Self.dot / 2, y: y - Self.dot / 2,
                                        width: Self.dot, height: Self.dot
                                    ))
                                    x += Self.pitch
                                }
                                y += Self.pitch
                            }
                        }
                        context.fill(dots, with: .color(CodeyColor.paperDot))
                    }
                }
            }
            .accessibilityHidden(true)
    }
}
