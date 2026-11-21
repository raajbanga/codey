import Foundation

// MARK: - [Pattern: Facade] Facade (groups, leaderboard)
/// Groups, invite codes and the weekly leaderboard (FR-42, FR-50–52).
/// Signed-in only; the last fetch is cached for offline display.
/// Part of the BackendFacade (§9.4).
extension BackendFacade {
    /// Last fetched groups, for offline display.
    var cachedGroups: GroupCache.Groups? { groupCache.groups() }

    func cachedLeaderboard(for groupID: UUID) -> GroupCache.Board? {
        groupCache.board(for: groupID)
    }

    func fetchGroups() async throws -> [GroupSummary] {
        let remote = try groupRemote()
        let groups = try await remote.fetchGroups()
        groupCache.setGroups(groups, at: now())
        return groups
    }

    /// FR-50. The server makes the invite code.
    func createGroup(name: String) async throws -> GroupSummary {
        let remote = try groupRemote()
        if let error = ModelValidator.validateGroupName(name).first { throw error }
        let group = try await remote.createGroup(id: UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        groupCache.upsert(group, at: now())
        return group
    }

    /// FR-51. Codes are case-insensitive.
    func joinGroup(code: String) async throws -> GroupSummary {
        let remote = try groupRemote()
        if let error = ModelValidator.validateInviteCode(code).first { throw error }
        let group = try await remote.joinGroup(code: ModelValidator.normalizedInviteCode(code))
        groupCache.upsert(group, at: now())
        return group
    }

    /// FR-52.
    func leaveGroup(_ group: GroupSummary) async throws {
        try await groupRemote().leaveGroup(id: group.id)
        groupCache.remove(group.id)
    }

    /// FR-42. Pushes this week's XP first (unless the caller just did), so
    /// your own row is current.
    func fetchLeaderboard(for groupID: UUID, syncFirst: Bool = true) async throws -> [LeaderboardEntry] {
        let remote = try groupRemote()
        if syncFirst { await engine.syncNow() }
        let entries = try await remote.fetchLeaderboard(groupID: groupID)
        groupCache.setBoard(entries, for: groupID, at: now())
        return entries
    }

    /// Every group's board (the Groups tab): one sync, then the fetches in
    /// parallel. A board that fails is left out; its cached copy stays.
    func fetchLeaderboards(for groupIDs: [UUID]) async -> [UUID: [LeaderboardEntry]] {
        guard !groupIDs.isEmpty, (try? groupRemote()) != nil else { return [:] }
        await engine.syncNow()
        return await withTaskGroup(of: (UUID, [LeaderboardEntry]?).self) { tasks in
            for id in groupIDs {
                tasks.addTask { (id, try? await self.fetchLeaderboard(for: id, syncFirst: false)) }
            }
            var boards: [UUID: [LeaderboardEntry]] = [:]
            for await (id, entries) in tasks {
                if let entries { boards[id] = entries }
            }
            return boards
        }
    }

    private func groupRemote() throws -> any RemoteDeckStore {
        guard let remote, currentUser != nil else { throw GroupError.signInRequired }
        return remote
    }
}
