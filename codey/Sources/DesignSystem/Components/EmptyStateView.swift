import SwiftUI

/// Friendly empty state for every empty list: symbol, title, message, and
/// an optional action.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(CodeyColor.brand)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                CodeyButton(actionTitle, action: action)
            }
        }
    }
}
