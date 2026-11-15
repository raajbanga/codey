import SwiftUI

/// FR-42: one group's board for this UTC week (S42 bento layout). The top
/// three stand on a podium of bars sized by XP, in each member's avatar
/// color; everyone else follows as rows with a bar against the leader.
/// Offline it shows the last board with an "as of" time.
///
///     You're 2nd, 170 XP behind Arnav
///     ╭ podium ───────────────────╮
///     │   (E)     (A)     (R)     │
///     │  ▇▇▇▇   ▇▇▇▇▇▇   ▇▇▇▇▇   │
///     ╰───────────────────────────╯
///     ╭ 4  (K) Kim  ▇▇▇░░░ 120 XP ╮
///     ╭ Invite: DZAU6S  [Share]   ╮
struct GroupBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BackendFacade.self) private var backend
    let group: GroupSummary

    @State private var board = CachedList<LeaderboardEntry>()
    @State private var confirmLeave = false
    @State private var actionError: String?

    private var rows: [LeaderboardRanking.Row] {
        LeaderboardRanking.rank(board.items, me: backend.currentUser?.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CodeySpacing.lg) {
                if let error = board.error {
                    StaleNotice(message: error, fetchedAt: board.fetchedAt)
                        .padding(CodeySpacing.md)
                        .codeyNote()
                }
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                        SectionTitle(standing)
                        Podium(rows: Array(rows.prefix(3)))
                        ForEach(rows.dropFirst(3)) { row in
                            BoardRow(row: row, leaderXP: rows.first?.entry.xp ?? 0)
                        }
                        Text("XP from quizzes since Monday 00:00 UTC.")
                            .font(.codeyCaption)
                            .foregroundStyle(CodeyColor.textSecondary)
                            .padding(.horizontal, CodeySpacing.xs)
                    }
                }
                VStack(alignment: .leading, spacing: CodeySpacing.sm) {
                    SectionTitle("Invite")
                    InviteCodeCard(group: group)
                }
                CodeyButton("Leave Group", systemImage: "xmark", kind: .destructive, fullWidth: true) {
                    confirmLeave = true
                }
                .accessibilityIdentifier("groups.leave")
            }
            .padding(CodeySpacing.md)
        }
        .codeyPaperBackground()
        .codeyPageTitle(group.name)
        .overlay {
            if board.isLoading, board.items.isEmpty { ProgressView() }
        }
        .refreshable { await load() }
        .task { await load() }
        .confirmationDialog("Leave \(group.name)?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave Group", role: .destructive, action: leave)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can join again with the code.")
        }
        .errorAlert($actionError)
    }

    /// "You're 2nd, 170 XP behind Arnav", "You're in the lead by 40 XP", or
    /// "This week" when you aren't on the board.
    private var standing: String {
        guard let me = rows.firstIndex(where: \.isMe) else { return "This week" }
        let row = rows[me]
        if me == 0 {
            guard rows.count > 1 else { return "You're in the lead" }
            let gap = row.entry.xp - rows[1].entry.xp
            return gap > 0 ? "You're in the lead by \(gap) XP" : "You're tied for 1st"
        }
        let ahead = rows[me - 1]
        let gap = ahead.entry.xp - row.entry.xp
        return gap > 0
            ? "You're \(Self.ordinal(row.rank)), \(gap) XP behind \(ahead.entry.displayName)"
            : "You're tied for \(Self.ordinal(row.rank))"
    }

    static func ordinal(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: n as NSNumber) ?? "\(n)"
    }

    private func load() async {
        await board.load(
            cached: backend.cachedLeaderboard(for: group.id).map { ($0.entries, $0.fetchedAt) },
            failure: "Couldn't refresh the board."
        ) { try await backend.fetchLeaderboard(for: group.id) }
    }

    private func leave() {
        Task {
            await $actionError.attempt("Couldn't leave the group. Check your connection and try again.") {
                try await backend.leaveGroup(group)
                dismiss()
            }
        }
    }
}

/// The top three as bars, 2nd, 1st, 3rd from left to right, each as tall
/// as its XP against the leader's.
private struct Podium: View {
    let rows: [LeaderboardRanking.Row]

    @ScaledMetric(relativeTo: .title) private var tallest: CGFloat = 150

    /// 2nd, 1st, 3rd (fewer members: whoever there is, leader in the middle).
    private var ordered: [LeaderboardRanking.Row] {
        switch rows.count {
        case 3: [rows[1], rows[0], rows[2]]
        case 2: [rows[1], rows[0]]
        default: rows
        }
    }

    var body: some View {
        let top = max(rows.first?.entry.xp ?? 0, 1)
        HStack(alignment: .bottom, spacing: CodeySpacing.sm) {
            ForEach(ordered) { row in
                PodiumColumn(row: row, height: barHeight(row.entry.xp, top: top))
            }
        }
        .padding(CodeySpacing.md)
        .padding(.top, CodeySpacing.xs)
        .frame(maxWidth: .infinity)
        .codeyNote()
    }

    /// At least a third of the tallest, so a 0 XP week still reads as a bar.
    private func barHeight(_ xp: Int, top: Int) -> CGFloat {
        let share = Double(max(xp, 0)) / Double(top)
        return tallest * (0.34 + 0.66 * share)
    }
}

private struct PodiumColumn: View {
    let row: LeaderboardRanking.Row
    let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    private var hue: CodeyColor.TopicHue { ProfileAvatar.color(for: row.entry.avatarId).hue }

    var body: some View {
        VStack(spacing: CodeySpacing.xs) {
            ProfileAvatarView(avatarId: row.entry.avatarId, size: row.rank == 1 ? 52 : 44)
            Text(row.entry.displayName)
                .font(.codeySubheadline.weight(row.isMe ? .semibold : .regular))
                .foregroundStyle(CodeyColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if row.isMe {
                CodeyChip("You", variant: .outline(CodeyColor.textSecondary))
            }
            VStack(spacing: CodeySpacing.xxs) {
                Text(GroupBoardView.ordinal(row.rank))
                    .font(.codeyHeadline)
                Text("\(row.entry.xp) XP")
                    .font(.codeySubheadline.weight(.medium).monospacedDigit())
                Spacer(minLength: 0)
            }
            .foregroundStyle(hue.onFill)
            .padding(.top, CodeySpacing.sm)
            .frame(maxWidth: .infinity)
            .frame(height: grown || reduceMotion ? height : height * 0.3)
            .background(hue.fill, in: UnevenRoundedRectangle(
                topLeadingRadius: CodeyRadius.md, bottomLeadingRadius: CodeyRadius.xs,
                bottomTrailingRadius: CodeyRadius.xs, topTrailingRadius: CodeyRadius.md, style: .continuous
            ))
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(CodeyMotion.resolve(CodeyMotion.smooth, reduceMotion: reduceMotion)) { grown = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(row.rank), \(row.entry.displayName)\(row.isMe ? ", you" : ""), \(row.entry.xp) XP")
    }
}

/// Fourth place and below: rank, avatar, name, XP, and a bar against the
/// leader's XP.
private struct BoardRow: View {
    let row: LeaderboardRanking.Row
    let leaderXP: Int

    private var hue: CodeyColor.TopicHue { ProfileAvatar.color(for: row.entry.avatarId).hue }

    var body: some View {
        HStack(spacing: CodeySpacing.sm) {
            Text("\(row.rank)")
                .font(.codeyNumericSmall)
                .foregroundStyle(CodeyColor.textSecondary)
                .frame(minWidth: 24, alignment: .leading)
            ProfileAvatarView(avatarId: row.entry.avatarId, size: 36)
            VStack(alignment: .leading, spacing: CodeySpacing.xs) {
                HStack {
                    Text(row.entry.displayName)
                        .font(.codeyBody.weight(row.isMe ? .semibold : .regular))
                        .lineLimit(1)
                    if row.isMe { CodeyChip("You", variant: .outline(CodeyColor.textSecondary)) }
                    Spacer(minLength: CodeySpacing.xs)
                    Text("\(row.entry.xp) XP")
                        .font(.codeySubheadline.weight(.medium).monospacedDigit())
                }
                .foregroundStyle(CodeyColor.textPrimary)
                ProgressBar(value: leaderXP > 0 ? Double(row.entry.xp) / Double(leaderXP) : 0,
                            tint: hue.fill, height: 8, track: hue.fill.opacity(0.22))
            }
        }
        .padding(CodeySpacing.md)
        .codeyNote()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(row.rank), \(row.entry.displayName)\(row.isMe ? ", you" : ""), \(row.entry.xp) XP")
    }
}
