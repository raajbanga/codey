import SwiftUI

/// The Ask AI chat (S39): a header, the conversation as notes on the
/// dotted paper (tutor replies rendered as Markdown), a typing indicator,
/// an error row with Retry, and the input bar.
///
///     ✦ Ask AI                            ✕
///       Explains the idea, never the answer
///     ╭ Hi! What part … ╮
///                      ╭ why is it O(n)? ╮
///     ╭ • bullets … ╮
///     [ Ask about this question…     (↑) ]
struct AskAIChatView: View {
    @Bindable var session: AskAISession
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            conversation
            inputBar
        }
        .codeyPaperBackground()
        .task { await session.start() }
    }

    private var header: some View {
        HStack(spacing: CodeySpacing.sm) {
            IconTile(systemName: "sparkles", size: 40, font: .codeyHeadline, radius: CodeyRadius.sm)
            VStack(alignment: .leading, spacing: CodeySpacing.xxs) {
                Text("Ask AI")
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.textPrimary)
                Text("Explains the idea, never the answer")
                    .font(.codeyCaption)
                    .foregroundStyle(CodeyColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            CloseButton(label: "Close Ask AI") { dismiss() }
                .accessibilityIdentifier("askAI.close")
        }
        .padding(.horizontal, CodeySpacing.md)
        .padding(.top, CodeySpacing.md)
        .padding(.bottom, CodeySpacing.sm)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: CodeySpacing.sm) {
                    ForEach(session.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                    if session.isWaiting {
                        TypingIndicator().id("typing")
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
        HStack(alignment: .bottom, spacing: CodeySpacing.sm) {
            TextField("Ask about this \(session.context.kind == .quiz ? "question" : "exercise")…", text: $session.draft, axis: .vertical)
                .font(.codeyBody)
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

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.codeyHeadline)
                    .foregroundStyle(CodeyColor.onBrandFill)
                    .frame(width: 44, height: 44)
                    .background(CodeyColor.brandFill, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!session.canSend)
            .opacity(session.canSend ? 1 : 0.45)
            .accessibilityLabel("Send")
            .accessibilityIdentifier("askAI.send")
        }
        .padding(.horizontal, CodeySpacing.md)
        .padding(.top, CodeySpacing.sm)
        .padding(.bottom, CodeySpacing.sm)
        .background(CodeyColor.surface)
        .overlay(alignment: .top) { Divider().overlay(CodeyColor.separator) }
        .sensoryFeedback(.impact(weight: .light), trigger: session.messages.count)
    }

    private func send() {
        guard session.canSend else { return }
        Task { await session.send() }
    }
}

/// One message. Tutor replies are notes on the left rendered as Markdown;
/// the student's are brand-soft notes on the right.
private struct ChatBubble: View {
    let message: AskAISession.Message

    var body: some View {
        switch message.role {
        case .tutor:
            CardMarkdownView(markdown: message.text)
                .padding(CodeySpacing.sm + CodeySpacing.xs)
                .codeyNote()
                .containerShape(.rect(cornerRadius: CodeyRadius.lg, style: .continuous))
                .padding(.trailing, CodeySpacing.lg)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tutor: \(message.text)")
                .accessibilityIdentifier("askAI.message.tutor")
        case .student:
            Text(message.text)
                .font(.codeyBody)
                .foregroundStyle(CodeyColor.textPrimary)
                .padding(.horizontal, CodeySpacing.md)
                .padding(.vertical, CodeySpacing.sm + CodeySpacing.xxs)
                .background(CodeyColor.brandSoft, in: .codey(CodeyRadius.lg))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, CodeySpacing.xl)
                .accessibilityLabel("You: \(message.text)")
                .accessibilityIdentifier("askAI.message.student")
        }
    }
}

/// Three ink dots that pulse in turn; a still "Thinking…" under Reduce Motion.
private struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Text("Thinking…")
                    .font(.codeySubheadline)
                    .foregroundStyle(CodeyColor.textSecondary)
            } else {
                TimelineView(.animation(minimumInterval: 0.15)) { timeline in
                    let phase = Int(timeline.date.timeIntervalSinceReferenceDate / 0.3) % 3
                    HStack(spacing: CodeySpacing.xs) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(CodeyColor.brand)
                                .frame(width: 8, height: 8)
                                .opacity(index == phase ? 1 : 0.3)
                        }
                    }
                    .codeyAnimation(value: phase)
                }
            }
        }
        .padding(.horizontal, CodeySpacing.md)
        .padding(.vertical, CodeySpacing.sm + CodeySpacing.xs)
        .codeyNote()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tutor is typing")
        .accessibilityIdentifier("askAI.typing")
    }
}

#if DEBUG
    #Preview {
        AskAIChatView(session: AskAISession(
            context: .quiz(id: "q1", topic: "Algorithms", difficulty: .easy, prompt: "What is the time complexity of binary search?",
                           options: ["O(1)", "O(log n)", "O(n)", "O(n²)"], correctIndex: 1),
            client: StubAskAIClient()
        ))
    }
#endif
