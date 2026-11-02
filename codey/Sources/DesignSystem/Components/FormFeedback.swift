import SwiftUI
import os

/// Inline validation message under a field (FR-10).
struct FieldErrorLabel: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.codeyCaption)
                .foregroundStyle(CodeyColor.danger)
        }
    }
}

/// "n/limit" counter that turns red past the limit. `unit` is shown after
/// the numbers ("12/80 lines"); without one it reads as characters.
struct LimitCounter: View {
    let count: Int
    let limit: Int
    var unit: String?

    var body: some View {
        Text("\(count)/\(limit)" + (unit.map { " \($0)" } ?? ""))
            .font(.codeyCaption.monospacedDigit())
            .foregroundStyle(count > limit ? CodeyColor.danger : CodeyColor.textSecondary)
            .accessibilityLabel("\(count) of \(limit) \(unit ?? "characters")")
    }
}

extension View {
    /// Danger outline on an invalid field.
    func errorBorder(_ isShown: Bool, radius: CGFloat) -> some View {
        // The hairline otherwise, so fields sit on the paper like notes (S9).
        overlay {
            RoundedRectangle.codey(radius).strokeBorder(
                isShown ? CodeyColor.danger : CodeyColor.separator,
                lineWidth: isShown ? 1.5 : 1
            )
        }
    }

    /// "Something Went Wrong" alert while `message` is non-nil.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert("Something Went Wrong", isPresented: message.isPresent()) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

extension Binding {
    /// True while the optional is set; setting false clears it.
    @MainActor
    func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(get: { wrappedValue != nil }, set: { if !$0 { wrappedValue = nil } })
    }
}

extension Binding where Value == String? {
    /// Runs `action`; a thrown error is logged and becomes the message that
    /// `errorAlert` shows.
    func attempt(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            Logger.persistence.error("Action failed: \(String(describing: error))")
            wrappedValue = error.localizedDescription
        }
    }

    /// For backend calls: a thrown error shows its own message if it has
    /// one (validation, invalid code), otherwise `fallback`.
    @MainActor
    func attempt(_ fallback: String, _ action: @MainActor () async throws -> Void) async {
        do {
            try await action()
        } catch {
            Logger.persistence.error("Action failed: \(String(describing: error))")
            wrappedValue = (error as? LocalizedError)?.errorDescription ?? fallback
        }
    }
}
