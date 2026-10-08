import SwiftUI

/// Glass ✕ that dismisses a focus-mode cover (study, quiz).
struct CloseButton: View {
    let label: String
    var hint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.codeyHeadline)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
    }
}
