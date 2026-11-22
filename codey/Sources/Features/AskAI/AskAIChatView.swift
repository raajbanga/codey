import SwiftUI

/// The Ask AI chat (S39), titled "Ask Codey" on screen (§3d), shown in a
/// FloatingPanel and laid out like quiz setup (Nov 15): the pastel
/// HeroCard on top, the conversation as notes on the dotted paper (tutor
/// replies rendered as Markdown), then the input, all at the panel's even
/// inset. No ✕: the panel is swiped away or tapped outside, like every
/// floating card.
///
///     ╭ (✦) Ask Codey       [Easy] ╮
///     ╰ Explains the idea, never…  ╯
///     ╭ Hi! What part … ╮
///                      ╭ why is it O(n)? ╮
///     [ Ask about this question…     (↑) ]
struct AskAIChatView: View {
    @Bindable var session: AskAISession
    @FocusState private var inputFocused: Bool
    @Environment(\.appHue) private var appHue

    var body: some View {
        // Gaps match the inset, as in quiz setup.
        VStack(spacing: CodeySpacing.lg) {
            header.padding([.horizontal, .top], CodeySpacing.lg)
            conversation
            inputRow.padding([.horizontal, .bottom], CodeySpacing.lg)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: session.messages.count)
        // A container, so the identifier names the panel and doesn't
        // replace the input's own (`askAI.input`).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("askAI.chat")
        .task { await session.start() }
    }

    /// The same hero as quiz setup: the name beside the icon, in the
    /// question's pastel (the quiz's hue), and the promise as its caption.
    private var header: some View {
        HeroCard(
            title: "Ask Codey",
            icon: "ask.ai",
            caption: "Explains the idea, never the answer"
        ) {
            if let tier = session.context.difficulty {
                CodeyChip(tier: tier)
            } else if let language = session.context.language {
                // Outlined, as on the exercise's own hero.
                CodeyChip(language.displayName, variant: .outline((appHue ?? .slate).ink))
            }
        }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: CodeySpacing.sm) {
                    ForEach(session.messages) { message in
                        ChatBubble(text: message.text, isMine: message.role == .student, speaker: "Tutor")
                            .accessibilityIdentifier(message.role == .student ? "askAI.message.student" : "askAI.message.tutor")
                            .id(message.id)
                    }
                    if session.isWaiting {
                        TypingIndicator(label: "Tutor is typing")
                            .accessibilityIdentifier("askAI.typing")
                            .id("typing")
                    }
                    if let error = session.error {
                        errorRow(error).id("error")
                    }
                }
                .padding(.horizontal, CodeySpacing.lg)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .codeyAnimation(value: session.messages.count)
            .codeyAnimation(value: session.isWaiting)
            .onChange(of: session.messages.count) { scrollToEnd(proxy) }
            .onChange(of: session.isWaiting) { scrollToEnd(proxy) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        let target: AnyHashable
        if session.error != nil {
            target = "error"
        } else if session.isWaiting {
            target = "typing"
        } else if let last = session.messages.last {
            target = last.id
        } else {
            return
        }
        withAnimation(CodeyMotion.smooth) { proxy.scrollTo(target, anchor: .bottom) }
    }

    private func errorRow(_ error: AskAIError) -> some View {
        CodeyCard(tint: CodeyColor.danger) {
            VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                Label(error.message, icon: "exclamationmark.triangle.fill")
                    .font(.codeySubheadline)
                    .foregroundStyle(CodeyColor.textPrimary)
                CodeyButton("Retry", systemImage: "arrow.clockwise", kind: .secondary, compact: true) {
                    Task { await session.retry() }
                }
                .accessibilityIdentifier("askAI.retry")
            }
        }
        .accessibilityIdentifier("askAI.error")
    }

    private var inputRow: some View {
        HStack(alignment: .center, spacing: CodeySpacing.sm) {
            TextField("Ask about this \(session.context.kind == .quiz ? "question" : "exercise")…", text: $session.draft, axis: .vertical)
                .font(.codeyCaption)
                .lineLimit(1...4)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit(send)
                .onChange(of: session.draft) { _, new in
                    if new.count > AskAISession.maxDraftLength { session.draft = String(new.prefix(AskAISession.maxDraftLength)) }
                }
                .codeyField()
                .accessibilityLabel("Message")
                .accessibilityIdentifier("askAI.input")

            CircleIconButton(systemImage: "arrow.up", label: "Send", kind: .filled, action: send)
                .disabled(!session.canSend)
                .accessibilityIdentifier("askAI.send")
        }
    }

    private func send() {
        guard session.canSend else { return }
        Task { await session.send() }
    }
}

#if DEBUG
    #Preview {
        Color.clear.floatingPanel(item: .constant(Optional(AskAISession(
            context: .quiz(id: "q1", topic: "Algorithms", difficulty: .easy, prompt: "What is the time complexity of binary search?",
                           options: ["O(1)", "O(log n)", "O(n)", "O(n²)"], correctIndex: 1),
            client: StubAskAIClient()
        ))), fillsHeight: true) { AskAIChatView(session: $0) }
    }
#endif
