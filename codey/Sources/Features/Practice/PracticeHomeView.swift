import SwiftUI

struct PracticeHomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: CodeySpacing.md) {
                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        HStack {
                            Image(systemName: "square.stack.fill")
                                .font(.title2)
                                .foregroundStyle(ThemeColor.primary)
                            Text("Quick Start")
                                .font(.codeyHeadline)
                        }

                        Text("Your daily study deck is ready. Sprint 2 will bring flashcard swiping, spaced repetition, and timed quiz modes.")
                            .font(.codeySubheadline)
                            .foregroundStyle(ThemeColor.muted)

                        HStack {
                            CodeyBadge("0 cards reviewed", variant: .neutral)
                            CodeyBadge("Mixed difficulty", variant: .warning)
                        }

                        CodeyProgress(value: 0, label: "Today's progress")

                        CodeyButton("Start Practice", variant: .ghost, size: .lg) {}
                    }
                }

                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("Coming in Sprint 2")
                            .font(.codeyHeadline)
                        Text("Swipe through flashcards, track answer streaks, and earn XP for every correct response.")
                            .font(.codeySubheadline)
                            .foregroundStyle(ThemeColor.muted)
                        CodeyButton("Browse Topics", variant: .outline) {}
                    }
                }
            }
            .padding(CodeySpacing.md)
        }
        .background(ThemeColor.canvas)
        .navigationTitle("Practice")
    }
}

#Preview {
    NavigationStack {
        PracticeHomeView()
    }
    .modelContainer(PreviewContainer.make())
}
