import SwiftUI
import UIKit

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

    /// The app's page background: warm paper with a faint dot grid. Also
    /// tints the page in brand ink: sheets don't inherit RootView's tint, so
    /// list buttons in them (Sign in with Google) fell back to system blue.
    func codeyPaperBackground() -> some View {
        background { PaperBackground().ignoresSafeArea() }
            .tint(CodeyColor.brand)
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

    var body: some View {
        CodeyColor.surface
            .overlay {
                if contrast == .standard {
                    Image(uiImage: Self.tile)
                        .renderingMode(.template)
                        .resizable(resizingMode: .tile)
                        .foregroundStyle(CodeyColor.paperDot)
                }
            }
            .accessibilityHidden(true)
    }

    /// One 20 pt cell with a 1.6 pt dot, drawn once and tiled. A template
    /// image, so the dot takes PaperDot's light/dark color at render time.
    private static let tile: UIImage = {
        let pitch: CGFloat = 20, dot: CGFloat = 1.6
        return UIGraphicsImageRenderer(size: CGSize(width: pitch, height: pitch)).image { _ in
            UIBezierPath(ovalIn: CGRect(x: (pitch - dot) / 2, y: (pitch - dot) / 2, width: dot, height: dot)).fill()
        }
        .withRenderingMode(.alwaysTemplate)
    }()
}
