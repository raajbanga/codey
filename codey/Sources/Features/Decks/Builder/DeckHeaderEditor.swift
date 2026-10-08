import SwiftUI

/// Title (n/60) + topic picker, with inline errors (FR-05, FR-10).
struct DeckHeaderEditor: View {
    @Bindable var viewModel: DeckViewModel
    let topics: [Topic]
    var titleFocused: FocusState<Bool>.Binding

    private var titleCount: Int { ModelValidator.measuredLength(viewModel.draft.title) }
    private var titleLimit: Int { ModelValidator.Limits.deckTitle.upperBound }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(spacing: CodeySpacing.sm) {
                TextField("Deck title", text: $viewModel.draft.title)
                    .font(.codeyHeadline)
                    .focused(titleFocused)
                    .submitLabel(.done)
                    .accessibilityIdentifier("builder.title")
                Text("\(titleCount)/\(titleLimit)")
                    .font(.codeyCaption.monospacedDigit())
                    .foregroundStyle(titleCount > titleLimit ? CodeyColor.danger : CodeyColor.textSecondary)
                    .accessibilityLabel("\(titleCount) of \(titleLimit) characters")
            }
            .padding(CodeySpacing.sm + CodeySpacing.xs)
            .background(CodeyColor.surfaceRaised, in: .codey(CodeyRadius.md))
            .overlay {
                if viewModel.error(for: .deckTitle) != nil {
                    RoundedRectangle.codey(CodeyRadius.md).strokeBorder(CodeyColor.danger, lineWidth: 1.5)
                }
            }
            fieldError(.deckTitle)

            Picker(selection: $viewModel.draft.topicId) {
                ForEach(topics) { topic in
                    Label(topic.title, systemImage: topic.iconName).tag(topic.id)
                }
            } label: {
                Text("Topic")
            }
            .pickerStyle(.menu)
            .tint(CodeyColor.brand)
            .accessibilityIdentifier("builder.topic")
            fieldError(.deckTopic)
        }
    }

    @ViewBuilder
    private func fieldError(_ field: ValidationField) -> some View {
        if let message = viewModel.error(for: field) {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.codeyCaption)
                .foregroundStyle(CodeyColor.danger)
        }
    }
}
