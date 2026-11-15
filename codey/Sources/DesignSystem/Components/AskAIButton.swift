import SwiftUI

/// Opens the Ask AI tutor (S39). Callers show it only when `AskAI.client`
/// exists (a key is configured).
struct AskAIButton: View {
    let action: () -> Void

    var body: some View {
        CircleIconButton(systemImage: "ask.ai", label: "Ask AI", kind: .soft, action: action)
            .accessibilityHint("Opens a tutor that explains the idea without giving the answer")
            .accessibilityIdentifier("askAI.open")
    }
}
