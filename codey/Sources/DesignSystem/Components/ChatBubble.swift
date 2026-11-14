import SwiftUI

/// One chat message (Ask AI, S39). The other side's messages are notes on
/// the left rendered as Markdown; yours are brand-soft notes on the right.
struct ChatBubble: View {
    let text: String
    let isMine: Bool
    /// VoiceOver name for the other side ("Tutor").
    var speaker = "Reply"

    var body: some View {
        if isMine {
            Text(text)
                .font(.codeyBody)
                .foregroundStyle(CodeyColor.textPrimary)
                .padding(.horizontal, CodeySpacing.md)
                .padding(.vertical, CodeySpacing.sm + CodeySpacing.xxs)
                .background(CodeyColor.brandSoft, in: .codey(CodeyRadius.lg))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, CodeySpacing.xl)
                .accessibilityLabel("You: \(text)")
        } else {
            CardMarkdownView(markdown: text)
                .padding(CodeySpacing.sm + CodeySpacing.xs)
                .codeyNote()
                .containerShape(.rect(cornerRadius: CodeyRadius.lg, style: .continuous))
                .padding(.trailing, CodeySpacing.lg)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(speaker): \(text)")
        }
    }
}

/// Three ink dots that pulse in turn on a small note; a still
/// "Thinking…" under Reduce Motion.
struct TypingIndicator: View {
    let label: String

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
        .accessibilityLabel(label)
    }
}
