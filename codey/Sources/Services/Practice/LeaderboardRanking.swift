import Foundation

/// FR-42 board order: XP high to low, ties share a rank (1, 1, 3), and tied
/// rows sort by name so the order is stable.
enum LeaderboardRanking {
    struct Row: Equatable, Identifiable {
        let rank: Int
        let entry: LeaderboardEntry
        let isMe: Bool

        var id: UUID { entry.userId }
    }

    static func rank(_ entries: [LeaderboardEntry], me: UUID?) -> [Row] {
        let sorted = entries.sorted { lhs, rhs in
            if lhs.xp != rhs.xp { return lhs.xp > rhs.xp }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
        var rows: [Row] = []
        for (index, entry) in sorted.enumerated() {
            let rank = index > 0 && sorted[index - 1].xp == entry.xp ? rows[index - 1].rank : index + 1
            rows.append(Row(rank: rank, entry: entry, isMe: entry.userId == me))
        }
        return rows
    }
}
