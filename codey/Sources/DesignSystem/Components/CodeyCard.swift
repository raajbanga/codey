import SwiftUI

/// Content card: raised surface, lg radius, no glass (glass is for the
/// control layer only). Children can use ConcentricRectangle /
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
