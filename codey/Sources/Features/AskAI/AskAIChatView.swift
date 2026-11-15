import SwiftUI

/// The Ask AI chat (S39), titled "Ask Codey" on screen (§3d), shown in a FloatingPanel: a header, the conversation as notes on the
/// dotted paper (tutor replies rendered as Markdown), a typing indicator,
/// an error row with Retry, and the input bar.
///
///     (✦) Ask Codey                       ✕
///     ╭ Hi! What part … ╮
///                      ╭ why is it O(n)? ╮
///     ╭ • bullets … ╮
///     [ Ask about this question…     (↑) ]
///        Explains the idea, never the answer
struct AskAIChatView: View {
    @Bindable var session: AskAISession
    @Environment(\.dismissPanel) private var dismissPanel
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            conversation
            inputBar
        }
        .task { await session.start() }
    }

    /// Round soft icon like the header buttons and the ✕ beside it (§3d),
    /// and the name only: the one-line promise sits by the input.
    private var header: some View {
        HStack(spacing: CodeySpacing.sm) {
            CircleIcon(systemImage: "ask.ai", kind: .soft)
                .accessibilityHidden(true)
            Text("Ask Codey")
                .font(.codeyHeadline)
                .foregroundStyle(CodeyColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            CloseButton(label: "Close Ask Codey") { dismissPanel() }
                .accessibilityIdentifier("askAI.close")
        }
        // Same insets as every floating card (codeyPanelPadding).
        .padding(.horizontal, CodeySpacing.md)
        .padding(.top, CodeySpacing.lg)
        .padding(.bottom, CodeySpacing.xs)
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
                .padding(CodeySpacing.md)
            }
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
                Label(error.message, systemImage: "exclamationmark.triangle.fill")
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

    private var inputBar: some View {
        VStack(spacing: CodeySpacing.xs) {
            inputRow
            Text("Explains the idea, never the answer")
                .font(.codeyCaption)
                .foregroundStyle(CodeyColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, CodeySpacing.md)
        .padding(.top, CodeySpacing.sm)
        .padding(.bottom, CodeySpacing.lg)
        .sensoryFeedback(.impact(weight: .light), trigger: session.messages.count)
    }

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: CodeySpacing.sm) {
            TextField("Ask about this \(session.context.kind == .quiz ? "question" : "exercise")…", text: $session.draft, axis: .vertical)
                .font(.codeyCallout)
                .lineLimit(1...4)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit(send)
                .onChange(of: session.draft) { _, new in
                    if new.count > AskAISession.maxDraftLength { session.draft = String(new.prefix(AskAISession.maxDraftLength)) }
                }
                .padding(.horizontal, CodeySpacing.md)
                .padding(.vertical, CodeySpacing.sm)
                .frame(minHeight: 44)
                .background(CodeyColor.surfaceRaised, in: .codey(CodeyRadius.lg))
                .overlay { RoundedRectangle.codey(CodeyRadius.lg).strokeBorder(CodeyColor.separator, lineWidth: 1) }
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
