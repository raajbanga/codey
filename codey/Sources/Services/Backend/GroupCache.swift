import Foundation

/// The last fetched groups and boards (FR-42 offline state: show the last
/// board with an "as of" time). UserDefaults JSON, decoded once and then
/// written through; cleared on sign-out.
final class GroupCache {
    struct Groups: Codable, Equatable {
        var groups: [GroupSummary]
        var fetchedAt: Date
    }

    struct Board: Codable, Equatable {
        var entries: [LeaderboardEntry]
        var fetchedAt: Date
    }

    private struct Stored: Codable {
        var groups: Groups?
        var boards: [UUID: Board] = [:]
    }

    private static let key = "groups.cache"

    let defaults: UserDefaults
    private lazy var stored: Stored = defaults.data(forKey: Self.key)
        .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) } ?? Stored()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func groups() -> Groups? { stored.groups }

    func board(for groupID: UUID) -> Board? { stored.boards[groupID] }

    func setGroups(_ groups: [GroupSummary], at date: Date) {
        update { stored in
            stored.groups = Groups(groups: groups, fetchedAt: date)
            // Boards for groups you've left go too.
            let ids = Set(groups.map(\.id))
            stored.boards = stored.boards.filter { ids.contains($0.key) }
        }
    }

    /// A created or joined group, before the next full fetch.
    func upsert(_ group: GroupSummary, at date: Date) {
        update { stored in
            var groups = stored.groups?.groups.filter { $0.id != group.id } ?? []
            groups.append(group)
            stored.groups = Groups(groups: groups, fetchedAt: stored.groups?.fetchedAt ?? date)
        }
    }

    func remove(_ groupID: UUID) {
        update { stored in
            stored.groups?.groups.removeAll { $0.id == groupID }
            stored.boards[groupID] = nil
        }
    }

    func setBoard(_ entries: [LeaderboardEntry], for groupID: UUID, at date: Date) {
        update { $0.boards[groupID] = Board(entries: entries, fetchedAt: date) }
    }

    func clear() {
        stored = Stored()
        defaults.removeObject(forKey: Self.key)
    }

    private func update(_ change: (inout Stored) -> Void) {
        change(&stored)
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
