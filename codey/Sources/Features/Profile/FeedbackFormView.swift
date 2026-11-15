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
        Form {
            if backend.currentUser == nil {
                Section {
                    Label("Sign in from your profile to send a report.", systemImage: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(CodeyColor.textSecondary)
                }
            } else if sent {
                Section {
                    Label("Thanks. Your report was sent.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(CodeyColor.success)
                }
            } else {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .focused($focused)
                        .accessibilityLabel("What went wrong")
                        .accessibilityIdentifier("feedback.text")
                } header: {
                    Text("What went wrong?")
                } footer: {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Say which screen and what you expected. Your app and iOS versions are included.")
                        Spacer(minLength: CodeySpacing.sm)
                        Text("\(length)/\(limit)")
                            .monospacedDigit()
                            .foregroundStyle(length > limit ? CodeyColor.danger : CodeyColor.textSecondary)
                    }
                    .font(.codeyCaption)
                }
            }
        }
        .codeyListBackground()
        .codeyPageTitle("Report an Issue")
        .toolbar {
            if backend.currentUser != nil, !sent {
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("Send") { send() }
                            .disabled(!isValid)
                            .accessibilityIdentifier("feedback.send")
                    }
                }
            }
        }
        .onAppear { focused = backend.currentUser != nil }
        .errorAlert($actionError)
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
