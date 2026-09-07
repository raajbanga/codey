import SwiftUI

struct PracticeHomeView: View {
    @Binding var selectedTab: AppTab

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

                        Text("Pick a topic and choose Practice for flashcard review or Quiz to earn XP.")
                            .font(.codeySubheadline)
                            .foregroundStyle(ThemeColor.muted)

                        HStack {
                            CodeyBadge("Flashcards", variant: .neutral)
                            CodeyBadge("XP in Quiz mode", variant: .success)
                        }

                        CodeyButton("Browse Topics", variant: .primary, size: .lg) {
                            selectedTab = .topics
                        }
                    }
                }

                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("How it works")
                            .font(.codeyHeadline)
                        Text("Practice mode lets you swipe through flashcards with tap-to-reveal answers — no grading. Quiz mode tests you with multiple choice and awards XP with streak bonuses.")
                            .font(.codeySubheadline)
                            .foregroundStyle(ThemeColor.muted)
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
        PracticeHomeView(selectedTab: .constant(.practice))
    }
    .modelContainer(ModelContainerFactory.makePreview())
}
