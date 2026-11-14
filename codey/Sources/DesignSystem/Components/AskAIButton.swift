import SwiftUI

/// Opens the Ask AI tutor (S39). A brand sparkle on the soft brand circle,
/// the same size as CloseButton so the two sit together in a top bar.
/// Callers show it only when `AskAI.client` exists (a key is configured).
struct AskAIButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sparkles")
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.brand)
                .frame(width: 44, height: 44)
                .background(CodeyColor.brandSoft, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask AI")
        .accessibilityHint("Opens a tutor that explains the idea without giving the answer")
        .accessibilityIdentifier("askAI.open")
    }
}
