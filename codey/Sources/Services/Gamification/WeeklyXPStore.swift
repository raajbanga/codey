import Foundation

/// FR-42: XP earned in the current UTC week, for the group leaderboard.
/// A small accumulator in UserDefaults that resets when the week changes
/// (QuizAnswerRecord doesn't keep XP). Synced as weekly_xp by SyncEngine.
struct WeeklyXPStore {
    /// Matches the weekly_xp.xp CHECK (500 answers × 45 XP).
    static let cap = 22_500

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let week = "weeklyXP.week"
        static let amount = "weeklyXP.amount"
        static let pushed = "weeklyXP.pushed"
    }

    /// This week's XP; 0 once the stored week is over.
    func xp(now: Date = .now) -> Int {
        defaults.string(forKey: Key.week) == UTCWeek.key(for: now) ? defaults.integer(forKey: Key.amount) : 0
    }

    func add(_ amount: Int, now: Date = .now) {
        guard amount > 0 else { return }
        let total = min(xp(now: now) + amount, Self.cap)
        defaults.set(UTCWeek.key(for: now), forKey: Key.week)
        defaults.set(total, forKey: Key.amount)
    }

    /// The last value the server acknowledged ("week|user|xp"), so a sync
    /// cycle only pushes when something changed.
    func needsPush(user: UUID, now: Date = .now) -> Bool {
        let current = xp(now: now)
        return current > 0 && defaults.string(forKey: Key.pushed) != pushKey(user: user, xp: current, now: now)
    }

    func markPushed(user: UUID, xp: Int, now: Date = .now) {
        defaults.set(pushKey(user: user, xp: xp, now: now), forKey: Key.pushed)
    }

    func reset() {
        [Key.week, Key.amount, Key.pushed].forEach(defaults.removeObject)
    }

    private func pushKey(user: UUID, xp: Int, now: Date) -> String {
        "\(UTCWeek.key(for: now))|\(user.uuidString)|\(xp)"
    }
}
