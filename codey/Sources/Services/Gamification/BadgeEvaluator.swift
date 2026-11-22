import Foundation
import SwiftData

/// What a badge counts. Each badge is "this count reaches that target".
enum BadgeMetric: CaseIterable, Sendable {
    case level, totalXP, streak, dailyGoals, weeklyChallenges
    case correctAnswers, hardTiers, topicsCompleted
    case drills, challenges
    case userDecks, decksMastered, cardsMastered

    /// The badge's shape in the trophy case (BadgeArt).
    var family: BadgeArt.Family {
        switch self {
        case .level: .level
        case .totalXP, .streak, .dailyGoals, .weeklyChallenges: .habit
        case .correctAnswers, .hardTiers, .topicsCompleted: .quiz
        case .drills, .challenges: .practice
        case .userDecks, .decksMastered: .decks
        case .cardsMastered: .cards
        }
    }
}

/// The badges (FR-35, S8; the trophy case, Nov 21). Earned once, kept
/// forever (BadgeAward), and each pays its XP once when it's awarded.
/// Case order is the trophy case's order. Raw values are stored and synced
/// (`badge_awards.badge` CHECK), so never rename one.
enum Badge: String, CaseIterable, Identifiable, Sendable {
    case level2, level5, level10, level20
    case xp1000, sevenDayStreak, streak30, dailyGoal10, weeklyChallenge
    case correct50, correct250, correct1000, hardTier, topic1, topics4
    case drill1, drills5, drills10, challenge1, challenges5
    case firstDeck, deck1, decks5, decks10
    case cards20, cards50, cards100

    var id: String { rawValue }

    private struct Spec {
        let metric: BadgeMetric
        let target: Int
        let xp: Int
        /// How to earn it, shown while it's locked.
        let requirement: String
        /// What was done, shown once it's earned.
        let title: String
        let glyph: String
        let hue: CodeyColor.TopicHue
        /// The number on the badge, if any.
        var numeral: String?
    }

    private var spec: Spec {
        switch self {
        case .level2: Spec(metric: .level, target: 2, xp: 25, requirement: "Reach Level 2", title: "Reached Level 2", glyph: "chevron.up.2", hue: .sky, numeral: "2")
        case .level5: Spec(metric: .level, target: 5, xp: 75, requirement: "Reach Level 5", title: "Reached Level 5", glyph: "chevron.up.2", hue: .sky, numeral: "5")
        case .level10: Spec(metric: .level, target: 10, xp: 150, requirement: "Reach Level 10", title: "Reached Level 10", glyph: "chevron.up.2", hue: .sky, numeral: "10")
        case .level20: Spec(metric: .level, target: 20, xp: 300, requirement: "Reach Level 20", title: "Reached Level 20", glyph: "chevron.up.2", hue: .sky, numeral: "20")
        case .xp1000: Spec(metric: .totalXP, target: 1_000, xp: 50, requirement: "Earn 1,000 XP", title: "Earned 1,000 XP", glyph: "star", hue: .gold)
        case .sevenDayStreak: Spec(metric: .streak, target: 7, xp: 100, requirement: "Keep a 7-Day Streak", title: "Kept a 7-Day Streak", glyph: "flame", hue: .coral, numeral: "7")
        case .streak30: Spec(metric: .streak, target: 30, xp: 300, requirement: "Keep a 30-Day Streak", title: "Kept a 30-Day Streak", glyph: "flame", hue: .coral, numeral: "30")
        case .dailyGoal10: Spec(metric: .dailyGoals, target: 10, xp: 100, requirement: "Meet the Daily Goal 10 Times", title: "Met the Daily Goal 10 Times", glyph: "flag", hue: .olive, numeral: "10")
        case .weeklyChallenge: Spec(metric: .weeklyChallenges, target: 1, xp: 100, requirement: "Finish a Weekly Challenge", title: "Finished a Weekly Challenge", glyph: "trophy", hue: .rose)
        case .correct50: Spec(metric: .correctAnswers, target: 50, xp: 50, requirement: "Answer 50 Correctly", title: "Answered 50 Correctly", glyph: "checkmark.bubble", hue: .indigo, numeral: "50")
        case .correct250: Spec(metric: .correctAnswers, target: 250, xp: 150, requirement: "Answer 250 Correctly", title: "Answered 250 Correctly", glyph: "checkmark.bubble", hue: .indigo, numeral: "250")
        case .correct1000: Spec(metric: .correctAnswers, target: 1_000, xp: 300, requirement: "Answer 1,000 Correctly", title: "Answered 1,000 Correctly", glyph: "checkmark.bubble", hue: .indigo, numeral: "1K")
        case .hardTier: Spec(metric: .hardTiers, target: 1, xp: 75, requirement: "Unlock a Hard Tier", title: "Unlocked a Hard Tier", glyph: "lock.open", hue: .plum)
        case .topic1: Spec(metric: .topicsCompleted, target: 1, xp: 150, requirement: "Complete a Topic", title: "Completed a Topic", glyph: "square.stack.3d.up", hue: .plum)
        case .topics4: Spec(metric: .topicsCompleted, target: 4, xp: 300, requirement: "Complete 4 Topics", title: "Completed 4 Topics", glyph: "square.stack.3d.up", hue: .plum, numeral: "4")
        case .drill1: Spec(metric: .drills, target: 1, xp: 25, requirement: "Complete a Drill", title: "Completed a Drill", glyph: "chevron.left.forwardslash.chevron.right", hue: .teal)
        case .drills5: Spec(metric: .drills, target: 5, xp: 50, requirement: "Complete 5 Drills", title: "Completed 5 Drills", glyph: "chevron.left.forwardslash.chevron.right", hue: .teal, numeral: "5")
        case .drills10: Spec(metric: .drills, target: 10, xp: 150, requirement: "Complete 10 Drills", title: "Completed 10 Drills", glyph: "chevron.left.forwardslash.chevron.right", hue: .teal, numeral: "10")
        case .challenge1: Spec(metric: .challenges, target: 1, xp: 50, requirement: "Solve a Challenge", title: "Solved a Challenge", glyph: "terminal", hue: .sand)
        case .challenges5: Spec(metric: .challenges, target: 5, xp: 200, requirement: "Solve 5 Challenges", title: "Solved 5 Challenges", glyph: "terminal", hue: .sand, numeral: "5")
        case .firstDeck: Spec(metric: .userDecks, target: 1, xp: 25, requirement: "Create a Deck", title: "Created a Deck", glyph: "plus.rectangle.on.rectangle", hue: .violet)
        case .deck1: Spec(metric: .decksMastered, target: 1, xp: 50, requirement: "Master a Deck", title: "Mastered a Deck", glyph: "checkmark.rectangle.stack", hue: .violet)
        case .decks5: Spec(metric: .decksMastered, target: 5, xp: 150, requirement: "Master 5 Decks", title: "Mastered 5 Decks", glyph: "checkmark.rectangle.stack", hue: .violet, numeral: "5")
        case .decks10: Spec(metric: .decksMastered, target: 10, xp: 300, requirement: "Master 10 Decks", title: "Mastered 10 Decks", glyph: "checkmark.rectangle.stack", hue: .violet, numeral: "10")
        case .cards20: Spec(metric: .cardsMastered, target: 20, xp: 50, requirement: "Master 20 Cards", title: "Mastered 20 Cards", glyph: "checkmark.rectangle.portrait", hue: .green, numeral: "20")
        case .cards50: Spec(metric: .cardsMastered, target: 50, xp: 100, requirement: "Master 50 Cards", title: "Mastered 50 Cards", glyph: "checkmark.rectangle.portrait", hue: .green, numeral: "50")
        case .cards100: Spec(metric: .cardsMastered, target: 100, xp: 200, requirement: "Master 100 Cards", title: "Mastered 100 Cards", glyph: "checkmark.rectangle.portrait", hue: .green, numeral: "100")
        }
    }

    var metric: BadgeMetric { spec.metric }
    var target: Int { spec.target }
    /// Paid once, when the badge is awarded (harder badges pay more).
    var xp: Int { spec.xp }
    var requirement: String { spec.requirement }
    var title: String { spec.title }
    /// A line icon name (Icon / icons.py).
    var symbol: String { spec.glyph }
    var hue: CodeyColor.TopicHue { spec.hue }
    var numeral: String? { spec.numeral }
    /// Inner rings on the badge: 1 up to 50 XP, 2 up to 150, 3 above.
    var rings: Int { xp <= 50 ? 1 : xp <= 150 ? 2 : 3 }

    var art: BadgeArt.Style {
        BadgeArt.Style(family: metric.family, glyph: symbol, hue: hue, numeral: numeral, rings: rings)
    }

    /// How far `facts` are toward this badge, capped at the target.
    func progress(_ facts: BadgeFacts) -> (value: Int, target: Int) {
        (min(facts[metric], target), target)
    }

    func fraction(_ facts: BadgeFacts) -> Double {
        Double(min(facts[metric], target)) / Double(target)
    }
}

/// What the badge rules look at, one count per metric (0 when not
/// gathered). Gathered from the store by `facts(in:)`, so the rules
/// themselves stay pure and testable.
struct BadgeFacts: Equatable {
    var values: [BadgeMetric: Int] = [:]

    init(_ values: [BadgeMetric: Int] = [:]) {
        self.values = values
    }

    subscript(metric: BadgeMetric) -> Int {
        get { values[metric] ?? 0 }
        set { values[metric] = newValue }
    }
}

enum BadgeEvaluator {
    /// Every badge these facts qualify for (earned before or not).
    static func qualifying(_ facts: BadgeFacts) -> Set<Badge> {
        Set(Badge.allCases.filter { facts[$0.metric] >= $0.target })
    }

    /// Inserts a BadgeAward for each newly qualifying badge, pays its XP,
    /// and returns them in `Badge.allCases` order. Badge XP can reach a
    /// level or 1,000 XP, so it checks again until nothing new qualifies.
    /// The XP goes to the total only, not this week's leaderboard XP, so
    /// catching up on many badges at once doesn't top a group's board.
    /// Doesn't save: callers run this right before their own save (deck
    /// save, quiz answer, card rating, solve). Runs on every answer and
    /// rating, so it only gathers the facts that unearned badges need;
    /// once all are earned it's a single fetch. Badges pulled from another
    /// device (ProgressSync) are inserted there and pay nothing here: that
    /// device paid, and total XP syncs as the larger of the two.
    @discardableResult
    static func award(context: ModelContext, now: Date = .now, calendar: Calendar = .current) throws -> [Badge] {
        var earned = Set(try context.fetch(FetchDescriptor<BadgeAward>()).compactMap(\.badge))
        let profile: UserProfile? = try context.first()
        var awarded: [Badge] = []
        while true {
            let unearned = Set(Badge.allCases).subtracting(earned)
            guard !unearned.isEmpty else { break }
            let qualifying = qualifying(try facts(in: context, for: unearned, now: now, calendar: calendar))
            let new = Badge.allCases.filter { unearned.contains($0) && qualifying.contains($0) }
            guard !new.isEmpty else { break }
            for badge in new {
                context.insert(BadgeAward(badge: badge, earnedAt: now))
                profile?.totalXP += badge.xp
                earned.insert(badge)
            }
            awarded += new
        }
        return awarded
    }

    /// The facts behind `badges`; the others stay 0. Counts in the store
    /// where it can rather than loading rows.
    static func facts(
        in context: ModelContext,
        for badges: Set<Badge> = Set(Badge.allCases),
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> BadgeFacts {
        let metrics = Set(badges.map(\.metric))
        var facts = BadgeFacts()
        let profile: UserProfile? = try context.first()
        let xp = profile?.totalXP ?? 0
        let solved = profile?.solvedExerciseIds ?? []

        for metric in metrics {
            switch metric {
            case .level:
                facts[.level] = LevelCalculator.level(forXP: xp)
            case .totalXP:
                facts[.totalXP] = xp
            case .streak, .dailyGoals:
                // Both read every day's total (this device and the others'):
                // a row per day and device, so a short fetch.
                let totals = StreakCalculator.dayTotals(
                    own: try context.fetch(FetchDescriptor<DailyActivity>()),
                    others: try context.fetch(FetchDescriptor<DeviceDayActivity>())
                )
                facts[.streak] = StreakCalculator.currentStreak(endingOn: now, totals: totals, calendar: calendar)
                facts[.dailyGoals] = totals.values.filter { $0 >= GatingConfig.standard.dailyGoal }.count
            case .weeklyChallenges:
                // This week's, or any past week whose bonus was paid.
                let done = try WeeklyChallenge.isComplete(context: context, now: now) || profile?.challengeBonusWeek != nil
                facts[.weeklyChallenges] = done ? 1 : 0
            case .correctAnswers:
                facts[.correctAnswers] = try context.fetch(FetchDescriptor<QuestionProgress>()).reduce(0) { $0 + $1.totalCorrect }
            case .hardTiers:
                facts[.hardTiers] = try context.fetchCount(FetchDescriptor<TopicProgress>(
                    predicate: #Predicate { $0.hardUnlockedAt != nil }
                ))
            case .topicsCompleted:
                facts[.topicsCompleted] = try topicsCompleted(in: context)
            case .drills:
                facts[.drills] = solved.filter { !$0.hasPrefix(Challenge.idPrefix) }.count
            case .challenges:
                facts[.challenges] = solved.filter { $0.hasPrefix(Challenge.idPrefix) }.count
            case .userDecks:
                let userOrigin = DeckOrigin.user.rawValue
                facts[.userDecks] = try context.fetchCount(FetchDescriptor<FlashcardDeck>(
                    predicate: #Predicate { $0.originRaw == userOrigin && $0.deletedAt == nil }
                ))
            case .decksMastered:
                facts[.decksMastered] = try context.fetch(FetchDescriptor<FlashcardDeck>(
                    predicate: #Predicate { $0.deletedAt == nil }
                )).filter(\.isFullyMastered).count
            case .cardsMastered:
                let mastered = Flashcard.maxMastery
                facts[.cardsMastered] = try context.fetchCount(FetchDescriptor<Flashcard>(
                    predicate: #Predicate { $0.deletedAt == nil && $0.masteryScore >= mastered }
                ))
            }
        }
        return facts
    }

    /// Topics with every question retired at once (what quiz setup calls
    /// "Topic mastered", across all tiers).
    private static func topicsCompleted(in context: ModelContext) throws -> Int {
        let retired = try context.fetch(FetchDescriptor<QuestionProgress>(predicate: #Predicate { $0.retiredAt != nil }))
        guard !retired.isEmpty else { return 0 }
        let retiredByTopic = Dictionary(grouping: retired, by: \.topicId).mapValues(\.count)
        return try context.fetch(FetchDescriptor<Topic>()).count { topic in
            let total = topic.questions.count
            return total > 0 && (retiredByTopic[topic.id] ?? 0) >= total
        }
    }
}
