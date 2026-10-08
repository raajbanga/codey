import SwiftUI

/// Content card: raised surface, lg radius, no glass (glass is for the
/// control layer only). Children can use ConcentricRectangle /
/// .containerShape-relative shapes to nest with matching corners.
struct CodeyCard<Content: View>: View {
    var padding: CGFloat = CodeySpacing.md
    var tint: Color?
    @ViewBuilder let content: Content

    init(padding: CGFloat = CodeySpacing.md, tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CodeyColor.surfaceRaised, in: .codey(CodeyRadius.lg))
            .overlay {
                if let tint {
                    RoundedRectangle.codey(CodeyRadius.lg)
                        .strokeBorder(tint, lineWidth: 1.5)
                }
            }
            .containerShape(.rect(cornerRadius: CodeyRadius.lg, style: .continuous))
    }
}
