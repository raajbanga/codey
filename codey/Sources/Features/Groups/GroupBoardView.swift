import SwiftUI

/// FR-42: one group's board for this UTC week. Rank, avatar, name, XP; your
/// row is highlighted. Offline it shows the last board with an "as of" time.
struct GroupBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BackendFacade.self) private var backend
    let group: GroupSummary

    @State private var entries: [LeaderboardEntry] = []
    @State private var fetchedAt: Date?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var confirmLeave = false
    @State private var actionError: String?

    private var rows: [LeaderboardRanking.Row] {
        LeaderboardRanking.rank(entries, me: backend.currentUser?.id)
    }

    var body: some View {
        List {
            if let loadError {
                Section {
                    StaleNotice(message: loadError, fetchedAt: fetchedAt)
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
            if isLoading, entries.isEmpty { ProgressView() }
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
        if entries.isEmpty, let cached = backend.cachedLeaderboard(for: group.id) {
            entries = cached.entries
            fetchedAt = cached.fetchedAt
        }
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await backend.fetchLeaderboard(for: group.id)
            fetchedAt = .now
            loadError = nil
        } catch {
            loadError = "Couldn't refresh the board."
        }
    }

    private func leave() {
        Task {
            do {
                try await backend.leaveGroup(group)
                dismiss()
            } catch {
                actionError = (error as? LocalizedError)?.errorDescription
                    ?? "Couldn't leave the group. Check your connection and try again."
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
