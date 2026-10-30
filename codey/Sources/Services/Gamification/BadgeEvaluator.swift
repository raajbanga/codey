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
    /// Set by the weekly challenge (S3-D); 0 until then.
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
    @discardableResult
    static func award(context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> [Badge] {
        let earned = Set(try context.fetch(FetchDescriptor<BadgeAward>()).compactMap(\.badge))
        let qualifying = qualifying(try facts(in: context, now: now, calendar: calendar))
        let new = Badge.allCases.filter { qualifying.contains($0) && !earned.contains($0) }
        for badge in new {
            context.insert(BadgeAward(badge: badge, earnedAt: now))
        }
        return new
    }

    static func facts(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> BadgeFacts {
        let userOrigin = DeckOrigin.user.rawValue
        let userDecks = try context.fetchCount(FetchDescriptor<FlashcardDeck>(
            predicate: #Predicate { $0.originRaw == userOrigin && $0.deletedAt == nil }
        ))
        let activity = try context.fetch(FetchDescriptor<DailyActivity>())
        let profile: UserProfile? = try context.first()
        return BadgeFacts(
            userDeckCount: userDecks,
            streak: StreakCalculator.currentStreak(endingOn: now, activity: activity, calendar: calendar),
            totalXP: profile?.totalXP ?? 0
        )
    }
}
