import SwiftUI

/// ✕ on a neutral circle that dismisses a focus-mode cover (study, quiz).
struct CloseButton: View {
    let label: String
    var hint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textSecondary)
                .frame(width: 44, height: 44)
                .background(CodeyColor.fillNeutral, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
    }
}
