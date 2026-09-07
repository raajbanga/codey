import SwiftData
import SwiftUI

struct AnalyticsDashboardView: View {
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    private var xpProgress: Double {
        guard let profile else { return 0 }
        let xpInLevel = profile.totalXP % 500
        return Double(xpInLevel) / 500.0
    }

    private var masteryPercent: Int {
        guard let profile, profile.totalXP > 0 else { return 0 }
        return min(profile.totalXP / 20, 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: CodeySpacing.md) {
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
                            statBlock(
                                value: "\(masteryPercent)%",
                                label: "Mastery",
                                badge: "Mock"
                            )
                        }

                        CodeyProgress(
                            value: xpProgress,
                            label: "XP to next level (\(profile?.totalXP ?? 0) / \(((profile?.totalXP ?? 0) / 500 + 1) * 500) XP)"
                        )
                    }
                }

                CodeyCard {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        Text("Sprint 2 Preview")
                            .font(.codeyHeadline)
                        Text("Detailed charts for daily activity, topic mastery breakdowns, and streak history will ship in Sprint 2.")
                            .font(.codeySubheadline)
                            .foregroundStyle(ThemeColor.muted)
                        HStack {
                            CodeyBadge("Weekly chart", variant: .neutral)
                            CodeyBadge("Topic heatmap", variant: .warning)
                            CodeyBadge("Streak calendar", variant: .success)
                        }
                    }
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
    .modelContainer(PreviewContainer.make())
}
