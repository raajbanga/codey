import SwiftUI

/// ✕ that closes a focus-mode cover (study, quiz) or a FloatingPanel.
struct CloseButton: View {
    let label: String
    var hint: String?
    let action: () -> Void

    var body: some View {
        CircleIconButton(systemImage: "xmark", label: label, action: action)
            .accessibilityHint(hint ?? "")
    }
}
