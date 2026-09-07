import SwiftUI

struct CodeyCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(CodeySpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ThemeColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ThemeColor.border, lineWidth: 1)
            }
    }
}
