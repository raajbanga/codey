import SwiftData
import SwiftUI

/// The four badges in a row (FR-35): earned ones in brand ink, locked ones
/// muted with a lock and how to earn them.
struct BadgesRow: View {
    @Query private var awards: [BadgeAward]

    private var earned: Set<Badge> { Set(awards.compactMap(\.badge)) }

    var body: some View {
        Grid(horizontalSpacing: CodeySpacing.sm, verticalSpacing: CodeySpacing.md) {
            GridRow {
                ForEach(Badge.allCases) { badge in
                    BadgeCell(badge: badge, isEarned: earned.contains(badge))
                }
            }
        }
        .padding(.vertical, CodeySpacing.xs)
    }
}

private struct BadgeCell: View {
    let badge: Badge
    let isEarned: Bool

    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 52

    var body: some View {
        VStack(spacing: CodeySpacing.xs) {
            Image(systemName: isEarned ? badge.symbol : "lock.fill")
                .font(isEarned ? .codeyTitle : .codeyHeadline)
                .foregroundStyle(isEarned ? CodeyColor.brand : CodeyColor.textSecondary)
                .frame(width: size, height: size)
                .background(isEarned ? CodeyColor.brandSoft : CodeyColor.fillNeutral, in: Circle())
            Text(badge.title)
                .font(.codeyCaption.weight(.medium))
                .foregroundStyle(isEarned ? CodeyColor.textPrimary : CodeyColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badge.title)
        .accessibilityValue(isEarned ? "Earned" : "Locked. \(badge.requirement)")
    }
}

extension View {
    /// Shows the quiet celebration banner when a new badge is awarded while
    /// this view is on screen (S9: no particles). `isActive` is false for a
    /// view hidden under a full-screen cover, so the banner shows once, on
    /// the cover, not twice.
    func badgeBanner(isActive: Bool = true) -> some View {
        modifier(BadgeBannerModifier(isActive: isActive))
    }
}

private struct BadgeBannerModifier: ViewModifier {
    let isActive: Bool

    @Query(sort: \BadgeAward.earnedAt) private var awards: [BadgeAward]
    /// Badges already on record when this view appeared, plus any shown
    /// since; nil until first appearance.
    @State private var seen: Set<String>?
    @State private var badge: Badge?
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if let badge {
                    CelebrationOverlay(isPresented: $isPresented, title: "Badge earned: \(badge.title)", systemImage: badge.symbol)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                if seen == nil { seen = Set(awards.map(\.badgeRaw)) }
            }
            .onChange(of: awards.map(\.badgeRaw)) { _, raws in
                let new = raws.filter { !(seen ?? []).contains($0) }
                seen = Set(raws)
                guard isActive, let raw = new.last, let earned = Badge(rawValue: raw) else { return }
                badge = earned
                isPresented = true
            }
    }
}

#Preview {
    List { Section("Badges") { BadgesRow() } }
        .modelContainer(ModelContainerFactory.makePreview())
}
