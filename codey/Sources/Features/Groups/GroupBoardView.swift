import SwiftUI

/// FR-42: one group's board for this UTC week. Rank, avatar, name, XP; your
/// row is highlighted. Offline it shows the last board with an "as of" time.
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
        List {
            if let error = board.error {
                Section {
                    StaleNotice(message: error, fetchedAt: board.fetchedAt)
                }
            }
            Section {
                ForEach(rows) { row in
                    BoardRow(row: row)
                        .listRowBackground(row.isMe ? CodeyColor.brandSoft : nil)
                }
            } header: {
                Text("This week")
            } footer: {
                Text("XP from quizzes since Monday 00:00 UTC.")
            }
            Section("Invite") {
                InviteCodeCard(group: group)
            }
            Section {
                Button("Leave Group", role: .destructive) { confirmLeave = true }
                    .accessibilityIdentifier("groups.leave")
            }
        }
        .codeyListBackground()
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
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

private struct BoardRow: View {
    let row: LeaderboardRanking.Row

    var body: some View {
        HStack(spacing: CodeySpacing.sm) {
            Text("\(row.rank)")
                .font(.codeyNumericSmall)
                .foregroundStyle(row.rank <= 3 ? CodeyColor.brand : CodeyColor.textSecondary)
                .frame(minWidth: 28, alignment: .leading)
            ProfileAvatarView(avatarId: row.entry.avatarId, size: 36)
            Text(row.isMe ? "\(row.entry.displayName) (you)" : row.entry.displayName)
                .font(.codeyBody)
                .fontWeight(row.isMe ? .semibold : .regular)
                .lineLimit(1)
            Spacer(minLength: CodeySpacing.xs)
            Text("\(row.entry.xp) XP")
                .font(.codeyNumericSmall)
                .foregroundStyle(CodeyColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(row.rank), \(row.entry.displayName)\(row.isMe ? ", you" : ""), \(row.entry.xp) XP")
    }
}
