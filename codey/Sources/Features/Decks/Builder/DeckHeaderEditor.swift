import SwiftUI

/// Title (n/60) + topic picker, with inline errors (FR-05, FR-10).
struct DeckHeaderEditor: View {
    @Bindable var viewModel: DeckViewModel
    let topics: [Topic]
    var titleFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack(spacing: CodeySpacing.sm) {
                TextField("Deck title", text: $viewModel.draft.title)
                    .font(.codeyHeadline)
                    .focused(titleFocused)
                    .submitLabel(.done)
                    .accessibilityIdentifier("builder.title")
                LimitCounter(
                    count: ModelValidator.measuredLength(viewModel.draft.title),
                    limit: ModelValidator.Limits.deckTitle.upperBound
                )
            }
            .padding(CodeySpacing.sm + CodeySpacing.xs)
            .background(CodeyColor.surfaceRaised, in: .codey(CodeyRadius.md))
            .errorBorder(viewModel.error(for: .deckTitle) != nil, radius: CodeyRadius.md)
            FieldErrorLabel(message: viewModel.error(for: .deckTitle))

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
            FieldErrorLabel(message: viewModel.error(for: .deckTopic))
        }
    }
}
