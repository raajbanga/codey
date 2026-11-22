import SwiftUI

/// Opens the Ask AI tutor (S39). Callers show it only when `AskAI.client`
/// exists (a key is configured).
struct AskAIButton: View {
    var hint = "Opens a tutor that explains the idea without giving the answer"
    let action: () -> Void

    var body: some View {
        CircleIconButton(systemImage: "ask.ai", label: "Ask Codey", kind: .soft, action: action)
            .accessibilityHint(hint)
            .accessibilityIdentifier("askAI.open")
    }
}
