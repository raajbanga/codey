import Foundation
import SwiftData

/// The badges (FR-35, S8). Earned once, kept forever (BadgeAward).
enum Badge: String, CaseIterable, Identifiable, Sendable {
    case firstDeck
    case sevenDayStreak
    case xp1000
    case weeklyChallenge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstDeck: "First Deck"
        case .sevenDayStreak: "7-Day Streak"
        case .xp1000: "1,000 XP"
        case .weeklyChallenge: "Weekly Challenge"
        }
    }

    /// How to earn it, shown while it's locked.
    var requirement: String {
        switch self {
        case .firstDeck: "Create your own deck"
        case .sevenDayStreak: "Meet the daily goal 7 days in a row"
        case .xp1000: "Earn 1,000 XP"
        case .weeklyChallenge: "Finish a weekly challenge"
        }
    }

    var symbol: String {
        switch self {
        case .firstDeck: "rectangle.stack.badge.plus"
        case .sevenDayStreak: "flame.fill"
        case .xp1000: "star.fill"
        case .weeklyChallenge: "trophy.fill"
        }
    }
}

/// What the badge rules look at. Gathered from the store by `facts(in:)`,
/// so the rules themselves stay pure and testable.
struct BadgeFacts: Equatable {
    var userDeckCount = 0
    var streak = 0
    var totalXP = 0
    /// 1 when this week's challenge (FR-43) is complete. The badge is kept
    /// once earned, so past weeks don't need counting.
    var weeklyChallengesCompleted = 0
}

enum BadgeEvaluator {
    static let streakTarget = 7
    static let xpTarget = 1_000

    /// Every badge these facts qualify for (earned before or not).
    static func qualifying(_ facts: BadgeFacts) -> Set<Badge> {
        var badges: Set<Badge> = []
        if facts.userDeckCount >= 1 { badges.insert(.firstDeck) }
        if facts.streak >= streakTarget { badges.insert(.sevenDayStreak) }
        if facts.totalXP >= xpTarget { badges.insert(.xp1000) }
        if facts.weeklyChallengesCompleted >= 1 { badges.insert(.weeklyChallenge) }
        return badges
    }

    /// Inserts a BadgeAward for each newly qualifying badge and returns
    /// them, in `Badge.allCases` order. Doesn't save: callers run this
    /// right before their own save (deck save, quiz answer, card rating).
    /// Runs on every answer and rating, so it only gathers the facts that
    /// unearned badges need; once all are earned it's a single fetch.
    @discardableResult
    static func award(context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> [Badge] {
        let earned = Set(try context.fetch(FetchDescriptor<BadgeAward>()).compactMap(\.badge))
        let unearned = Set(Badge.allCases).subtracting(earned)
        guard !unearned.isEmpty else { return [] }
        let qualifying = qualifying(try facts(in: context, for: unearned, now: now, calendar: calendar))
        let new = Badge.allCases.filter { unearned.contains($0) && qualifying.contains($0) }
        for badge in new {
            context.insert(BadgeAward(badge: badge, earnedAt: now))
        }
        return new
    }

    /// The facts behind `badges`; the others stay 0. Counts in the store
    /// rather than loading rows. The streak only looks back far enough to
    /// reach `streakTarget`, so a longer streak reads as `streakTarget + 1`.
    static func facts(
        in context: ModelContext,
        for badges: Set<Badge> = Set(Badge.allCases),
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> BadgeFacts {
        var facts = BadgeFacts()
        if badges.contains(.firstDeck) {
            let userOrigin = DeckOrigin.user.rawValue
            facts.userDeckCount = try context.fetchCount(FetchDescriptor<FlashcardDeck>(
                predicate: #Predicate { $0.originRaw == userOrigin && $0.deletedAt == nil }
            ))
        }
        if badges.contains(.sevenDayStreak) {
            // Today (which may not count yet) plus streakTarget days before it.
            let days = (0...streakTarget).compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
                .map { DailyActivity.dayKey(for: $0, calendar: calendar) }
            let recent = try context.fetch(FetchDescriptor<DailyActivity>(predicate: #Predicate { days.contains($0.day) }))
            facts.streak = StreakCalculator.currentStreak(endingOn: now, activity: recent, calendar: calendar)
        }
        if badges.contains(.xp1000) {
            let profile: UserProfile? = try context.first()
            facts.totalXP = profile?.totalXP ?? 0
        }
        if badges.contains(.weeklyChallenge) {
            var topics = FetchDescriptor<Topic>()
            topics.propertiesToFetch = [\.id]
            if let topic = WeeklyChallenge.topicID(for: now, topicIDs: try context.fetch(topics).map(\.id)) {
                let start = UTCWeek.start(of: now)
                let correct = try context.fetchCount(FetchDescriptor<QuizAnswerRecord>(
                    predicate: #Predicate { $0.topicId == topic && $0.correct == true && $0.answeredAt >= start }
                ))
                facts.weeklyChallengesCompleted = correct >= WeeklyChallenge.goal ? 1 : 0
            }
        }
        return facts
    }
}
