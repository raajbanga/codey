#if DEBUG
import SwiftUI

/// Every design-system component on one screen, for visual QA (ES) in light,
/// dark, and large Dynamic Type. Previews only, so Debug builds only.
struct ComponentGallery: View {
    @State private var answer: AnswerOptionState = .idle
    @State private var xp = 1_840
    @State private var celebrate = false
    @State private var prompt = "What does **`defer`** do?"
    @State private var code = "for i in range(3):\n    print(i)"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                section("Colors") { colors }
                section("Buttons") { buttons }
                section("Chips & tiers") { chips }
                section("Answer rows") { answers }
                section("Progress & stats") { progress }
                section("Card markdown") {
                    CodeyCard {
                        CardMarkdownView(
                            markdown: "Which loop prints `0 1 2`?\n\n1. A `for` loop\n2. A *while* loop",
                            snippet: CodeSnippet(language: .python, source: code)
                        )
                    }
                }
                section("Editors") {
                    MarkdownTextEditor(title: "Prompt", text: $prompt)
                    CodeEditorView(text: $code, language: .python)
                        .frame(height: 160)
                        .clipShape(.codey(CodeyRadius.md))
                }
                section("Empty state") {
                    EmptyStateView(
                        systemImage: "rectangle.stack.badge.plus",
                        title: "No decks yet",
                        message: "Make your first deck or start with a starter deck.",
                        actionTitle: "New Deck",
                        action: {}
                    )
                }
            }
            .padding(CodeySpacing.md)
        }
        .background(CodeyColor.surface)
        .overlay { CelebrationOverlay(isPresented: $celebrate, title: "Level 5!", systemImage: "star.circle.fill") }
    }

    private var colors: some View {
        let swatches: [(String, Color)] = [
            ("brand", CodeyColor.brand), ("brandFill", CodeyColor.brandFill), ("onBrandFill", CodeyColor.onBrandFill),
            ("brandSoft", CodeyColor.brandSoft), ("surface", CodeyColor.surface), ("separator", CodeyColor.separator),
            ("success", CodeyColor.success), ("warning", CodeyColor.warning), ("danger", CodeyColor.danger),
            ("easy", CodeyColor.Tier.easy), ("medium", CodeyColor.Tier.medium), ("hard", CodeyColor.Tier.hard),
            ("easySoft", CodeyColor.Soft.easy), ("mediumSoft", CodeyColor.Soft.medium), ("hardSoft", CodeyColor.Soft.hard),
        ] + SyntaxRole.allCases.map { ("\($0)", $0.color) }
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: CodeySpacing.sm) {
            ForEach(swatches, id: \.0) { name, color in
                VStack(spacing: CodeySpacing.xxs) {
                    RoundedRectangle.codey(CodeyRadius.sm).fill(color).frame(height: 36)
                    Text(name).font(.codeyCaption).foregroundStyle(CodeyColor.textSecondary)
                }
            }
        }
    }

    private var buttons: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            CodeyButton("Start Quiz", systemImage: "play.fill", fullWidth: true) {}
            HStack {
                CodeyButton("Secondary", kind: .secondary) {}
                CodeyButton("Primary") {}
            }
            HStack {
                CodeyButton("Compact", kind: .secondary, compact: true) {}
                CodeyButton("Quiz", compact: true) {}
                CodeyButton("Delete", kind: .destructive) {}
            }
        }
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            HStack {
                ForEach(Difficulty.allCases, id: \.self) { CodeyChip(tier: $0) }
            }
            HStack {
                CodeyChip("12 cards")
                CodeyChip("Synced", systemImage: "checkmark.icloud", variant: .success)
                CodeyChip("🔥 3", variant: .warning)
                CodeyChip("New", variant: .brand)
            }
            TierChipRow(tiers: [
                TierAvailability(difficulty: .easy, isUnlocked: true),
                TierAvailability(difficulty: .medium, isUnlocked: true),
                TierAvailability(difficulty: .hard, isUnlocked: false, lockReason: "Reach Level 3 · 420 XP to go"),
            ])
        }
    }

    private var answers: some View {
        VStack(spacing: CodeySpacing.sm) {
            AnswerOptionRow(index: 0, title: "O(1) on average, because a good hash function spreads keys evenly across buckets", state: answer, isLocked: answer != .idle) {
                answer = .selectedCorrect
            }
            AnswerOptionRow(index: 1, title: "O(n)", state: answer == .idle ? .idle : .selectedWrong, isLocked: answer != .idle) {}
            AnswerOptionRow(index: 2, title: "O(log n)", state: .revealedCorrect, isLocked: true) {}
            Button("Reset") { answer = .idle }.font(.codeyCaption)
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: CodeySpacing.md) {
            HStack(spacing: CodeySpacing.md) {
                ProgressRing(value: LevelCalculator.progressFraction(xp), lineWidth: 10) {
                    Text("Lv \(LevelCalculator.level(forXP: xp))").font(.codeyNumericSmall)
                }
                .frame(width: 84, height: 84)
                VStack(alignment: .leading) {
                    XPGainLabel(total: xp)
                    Button("+25 XP") {
                        xp += 25
                    }
                    Button("Celebrate") { celebrate = true }
                }
            }
            ProgressBar(value: 0.62, label: "Deck mastery")
            HStack {
                StatTile(value: 8, label: "Correct", suffix: "/10")
                StatTile(value: xp, label: "Total XP", systemImage: "sparkles")
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CodeySpacing.sm) {
            Text(title).font(.codeyTitle)
            content()
        }
    }
}

#Preview("Light") {
    ComponentGallery().preferredColorScheme(.light)
}

#Preview("Dark") {
    ComponentGallery().preferredColorScheme(.dark)
}

#Preview("AX3 text") {
    ComponentGallery().environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("XS text, dark") {
    ComponentGallery().environment(\.dynamicTypeSize, .xSmall).preferredColorScheme(.dark)
}
#endif
