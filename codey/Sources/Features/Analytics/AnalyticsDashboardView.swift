import SwiftData
import SwiftUI

struct AnalyticsDashboardView: View {
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    private var totalXP: Int { profile?.totalXP ?? 0 }

    var body: some View {
        ScrollView {
            CodeyCard {
                VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                    Text("Your Stats")
                        .font(.codeyHeadline)

                    HStack(spacing: CodeySpacing.lg) {
                        statBlock(
                            value: "\(totalXP)",
                            label: "Total XP",
                            badge: "Level \(LevelCalculator.level(forXP: totalXP))"
                        )
                        statBlock(
                            value: "\(profile?.currentStreak ?? 0)",
                            label: "Day Streak",
                            badge: (profile?.currentStreak ?? 0) > 0 ? "Active" : "Start today"
                        )
                    }

                    ProgressBar(
                        value: LevelCalculator.progressFraction(totalXP),
                        label: "XP to next level (\(totalXP) / \(LevelCalculator.xpForNextLevel(totalXP)) XP)"
                    )
                }
            }
            .padding(CodeySpacing.md)
        }
        .background(CodeyColor.surface)
        .navigationTitle("Analytics")
    }

    @ViewBuilder
    private func statBlock(value: String, label: String, badge: String) -> some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            Text(value)
                .font(.codeyNumeric)
                .foregroundStyle(CodeyColor.brand)
            Text(label)
                .font(.codeyCaption)
                .foregroundStyle(CodeyColor.textSecondary)
            CodeyChip(badge, variant: .neutral)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        AnalyticsDashboardView()
    }
    .modelContainer(ModelContainerFactory.makePreview())
}
