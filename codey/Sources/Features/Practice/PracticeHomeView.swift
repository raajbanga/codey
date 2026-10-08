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
                                .font(.codeyTitle)
                                .foregroundStyle(CodeyColor.brand)
                            Text("Quick Start")
                                .font(.codeyHeadline)
                        }

                        Text("Pick a topic and choose Practice for flashcard review or Quiz to earn XP.")
                            .font(.codeySubheadline)
                            .foregroundStyle(CodeyColor.textSecondary)

                        HStack {
                            CodeyChip("Flashcards", variant: .neutral)
                            CodeyChip("XP in Quiz mode", variant: .success)
                        }

                        CodeyButton("Browse Topics", fullWidth: true) {
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
                            .foregroundStyle(CodeyColor.textSecondary)
                    }
                }
            }
            .padding(CodeySpacing.md)
        }
        .background(CodeyColor.surface)
        .navigationTitle("Practice")
    }
}

#Preview {
    NavigationStack {
        PracticeHomeView(selectedTab: .constant(.practice))
    }
    .modelContainer(ModelContainerFactory.makePreview())
}
