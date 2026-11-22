import SwiftUI

/// FR-49: "Report a UI/UX issue". Signed-in only; sent straight to the
/// server through BackendFacade. On failure the text stays for a retry.
struct FeedbackFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BackendFacade.self) private var backend

    @State private var text = ""
    @State private var isSending = false
    @State private var sent = false
    @State private var actionError: String?
    @FocusState private var focused: Bool

    private var limit: Int { ModelValidator.Limits.feedback.upperBound }
    private var length: Int { ModelValidator.measuredLength(text) }
    private var isValid: Bool { ModelValidator.validateFeedback(text).isEmpty }

    var body: some View {
        CodeyPage("Report an Issue", subtitle: "Tell us what broke. We read every report.", icon: "exclamationmark.bubble") {
            if backend.currentUser != nil, !sent {
                PageAction(systemImage: "paperplane", label: "Send", isWorking: isSending, action: send)
                    .disabled(!isValid)
                    .accessibilityIdentifier("feedback.send")
            }
        } content: {
            if backend.currentUser == nil {
                status("Sign in from your profile to send a report.", icon: "person.crop.circle.badge.questionmark", color: CodeyColor.textSecondary)
            } else if sent {
                status("Thanks. Your report was sent.", icon: "checkmark.circle.fill", color: CodeyColor.success)
            } else {
                NoteGroup("What went wrong?", footer: "Say which screen and what you expected. Your app and iOS versions are included.") {
                    TextEditor(text: $text)
                        .font(.codeyBody)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 160)
                        .focused($focused)
                        .accessibilityLabel("What went wrong")
                        .accessibilityIdentifier("feedback.text")
                    HStack {
                        Spacer(minLength: 0)
                        LimitCounter(count: length, limit: limit)
                    }
                }
            }
        }
        .onAppear { focused = backend.currentUser != nil }
        .errorAlert($actionError)
    }

    /// One line in a note, for the signed-out and sent states.
    private func status(_ text: String, icon: String, color: Color) -> some View {
        Label(text, icon: icon)
            .font(.codeyBody)
            .foregroundStyle(color)
            .codeyCard()
    }

    private func send() {
        isSending = true
        Task {
            defer { isSending = false }
            await $actionError.attempt("Couldn't send the report. Check your connection and try again.") {
                try await backend.submitFeedback(text)
                withAnimation(CodeyMotion.smooth) { sent = true }
            }
        }
    }
}
