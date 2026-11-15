import SwiftUI

/// Title (n/60) + topic, with inline errors (FR-05, FR-10).
///
/// Drawn like the deck's own tile on Decks (§3b): a pastel note in the
/// topic's hue with the topic icon, so picking a topic recolors it and the
/// header previews what the saved deck will look like.
///
///     ╭──────────────────────────────╮
///     │ ⟨icon⟩              (Topic ⌄) │
///     │ Deck title                    │
///     │ 3 cards                 12/60 │
///     ╰──────────────────────────────╯
struct DeckHeaderEditor: View {
    @Bindable var viewModel: DeckViewModel
    let topics: [Topic]
    var titleFocused: FocusState<Bool>.Binding

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var topic: Topic? { topics.first { $0.id == viewModel.draft.topicId } }
    private var hue: CodeyColor.TopicHue { .of(topicID: viewModel.draft.topicId) }
    private var titleError: String? { viewModel.error(for: .deckTitle) }

    var body: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                HStack(alignment: .center, spacing: CodeySpacing.sm) {
                    Icon(topic?.iconName ?? "rectangle.stack", size: 26, relativeTo: .title2)
                        .foregroundStyle(hue.ink)
                        .accessibilityHidden(true)
                    Spacer(minLength: 0)
                    topicMenu
                }

                // Single line: UI tests find it as a text field.
                TextField("Deck title", text: $viewModel.draft.title)
                    .font(.codeyTitle)
                    .foregroundStyle(hue.ink)
                    .focused(titleFocused)
                    .submitLabel(.done)
                    .onSubmit { titleFocused.wrappedValue = false }
                    .padding(.top, CodeySpacing.xxs)
                    .accessibilityIdentifier("builder.title")

                HStack {
                    Text(viewModel.draft.cards.count.counted("card"))
                        .font(.codeySubheadline)
                        .monospacedDigit()
                        .foregroundStyle(hue.ink)
                        .contentTransition(.numericText())
                    Spacer(minLength: 0)
                    LimitCounter(
                        count: ModelValidator.measuredLength(viewModel.draft.title),
                        limit: ModelValidator.Limits.deckTitle.upperBound
                    )
                }
            }
            .padding(CodeySpacing.md)
            .codeyNote(fill: hue.soft, edge: titleError != nil ? CodeyColor.danger : hue.soft)
            // A pastel is light in both modes (two-tone), like GameTile.
            .environment(\.colorScheme, .light)
            .animation(reduceMotion ? nil : CodeyMotion.snappy, value: viewModel.draft.topicId)

            FieldErrorLabel(message: titleError)
            FieldErrorLabel(message: viewModel.error(for: .deckTopic))
        }
    }

    /// The topic as a tag that opens a menu, instead of a bare menu label.
    private var topicMenu: some View {
        Menu {
            Picker("Topic", selection: $viewModel.draft.topicId) {
                ForEach(topics) { topic in
                    Label(topic.title, systemImage: topic.iconName).tag(topic.id)
                }
            }
        } label: {
            CodeyChip(topic?.title ?? "Pick a topic", systemImage: "chevron.up.chevron.down", variant: .outline(hue.ink))
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Topic")
        .accessibilityValue(topic?.title ?? "None")
        .accessibilityIdentifier("builder.topic")
    }
}
