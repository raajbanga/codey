import SwiftData
import SwiftUI

struct AnalyticsDashboardView: View {
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    private var xpProgress: Double {
        guard let profile else { return 0 }
        return Double(profile.totalXP % 500) / 500.0
    }

    var body: some View {
        ScrollView {
            CodeyCard {
                VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                    Text("Your Stats")
                        .font(.codeyHeadline)

                    HStack(spacing: CodeySpacing.lg) {
                        statBlock(
                            value: "\(profile?.totalXP ?? 0)",
                            label: "Total XP",
                            badge: "Level \(max((profile?.totalXP ?? 0) / 500 + 1, 1))"
                        )
                        statBlock(
                            value: "\(profile?.currentStreak ?? 0)",
                            label: "Day Streak",
                            badge: (profile?.currentStreak ?? 0) > 0 ? "Active" : "Start today"
                        )
                    }

                    CodeyProgress(
                        value: xpProgress,
                        label: "XP to next level (\(profile?.totalXP ?? 0) / \(((profile?.totalXP ?? 0) / 500 + 1) * 500) XP)"
                    )
                }
            }
            .padding(CodeySpacing.md)
        }
        .background(ThemeColor.canvas)
        .navigationTitle("Analytics")
    }

    @ViewBuilder
    private func statBlock(value: String, label: String, badge: String) -> some View {
        VStack(alignment: .leading, spacing: CodeySpacing.xs) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(ThemeColor.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(ThemeColor.muted)
            CodeyBadge(badge, variant: .neutral)
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
