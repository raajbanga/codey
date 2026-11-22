import Foundation

/// Pure helpers behind HomeView (unit-tested).
enum HomeLogic {
    /// Every topic, pinned first (in pin order), then the rest by title.
    static func orderedTopicIDs(all: [(id: String, title: String)], pinned: [String]) -> [String] {
        let known = Set(all.map(\.id))
        let pins = pinned.filter(known.contains)
        let rest = all
            .filter { !pins.contains($0.id) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            .map(\.id)
        return pins + rest
    }

    /// O9: the suggested quiz is on the weakest topic, chosen from the
    /// pinned topics (all topics if none are pinned). An untried topic
    /// counts as weakest (0%); ties keep the given order.
    static func weakestTopicID(candidates: [String], accuracy: [String: Double]) -> String? {
        var best: (id: String, score: Double)?
        for id in candidates {
            let score = accuracy[id] ?? 0
            if best == nil || score < best!.score {
                best = (id, score)
            }
        }
        return best?.id
    }

    /// What Play's warm-up quest suggests.
    enum UpNext: Equatable {
        /// A saved study session (newest first).
        case resume(deckID: UUID, position: Int, total: Int)
        /// New learner: start with a starter deck.
        case startDeck(deckID: UUID)
        /// Otherwise: a quiz on the weakest pinned topic (opens setup).
        case quiz(topicID: String)
        case none
    }

    /// Priority: resume > (new learner) starter deck > weakest-topic quiz.
    static func upNext(
        resumable: (deckID: UUID, position: Int, total: Int)?,
        isNewLearner: Bool,
        starterDeckID: UUID?,
        weakestTopicID: String?
    ) -> UpNext {
        if let resumable { return .resume(deckID: resumable.deckID, position: resumable.position, total: resumable.total) }
        if isNewLearner, let starterDeckID { return .startDeck(deckID: starterDeckID) }
        if let weakestTopicID { return .quiz(topicID: weakestTopicID) }
        return .none
    }
}

/// Everything Home derives from its queries, built once per render and
/// passed to each section, instead of recomputed per row and per topic.
struct HomeStats {
    /// FR-36 accuracy over each topic's newest `window` answers.
    let accuracyByTopic: [String: Double]
    /// Answers per topic, capped at `window` (the ones accuracy covers).
    let answerCounts: [String: Int]
    /// Each topic's visible decks: starter decks first, then the user's, by title.
    let decksByTopic: [String: [FlashcardDeck]]
    let deckByID: [UUID: FlashcardDeck]
    let snapshotDeckIDs: Set<UUID>

    /// `records` must be newest first.
    init(
        records: [QuizAnswerRecord],
        decks: [FlashcardDeck],
        snapshots: [StudyProgressSnapshot],
        window: Int = GatingConfig.standard.accuracyWindow
    ) {
        var counts: [String: Int] = [:]
        var correct: [String: Int] = [:]
        for record in records where counts[record.topicId, default: 0] < window {
            counts[record.topicId, default: 0] += 1
            if record.correct { correct[record.topicId, default: 0] += 1 }
        }
        answerCounts = counts
        accuracyByTopic = counts.reduce(into: [:]) { result, entry in
            result[entry.key] = Double(correct[entry.key] ?? 0) / Double(entry.value)
        }
        decksByTopic = Dictionary(grouping: decks.filter { !$0.isHidden && $0.hasActiveCards }, by: \.topicId)
            .mapValues { decks in
                decks.sorted { lhs, rhs in
                    if lhs.origin != rhs.origin { return lhs.origin == .starter }
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
            }
        deckByID = decks.keyed(by: \.id)
        snapshotDeckIDs = Set(snapshots.map(\.deckId))
    }
}

/// What Play's quest bentos show this launch: today's quests, or the
/// badges closest to done. Flips once per launch (LoadingView), so the
/// row changes between visits, never while it's on screen.
enum PlayRotation {
    static let key = "play.showsBadgeQuests"

    static func advance(defaults: UserDefaults = .standard) {
        defaults.set(!defaults.bool(forKey: key), forKey: key)
    }
}

extension HomeLogic {
    /// The unearned badges closest to done: most progress first, then the
    /// smaller reward, then trophy-case order.
    static func nextBadges(earned: Set<Badge>, facts: BadgeFacts, limit: Int = 3) -> [Badge] {
        let order = Dictionary(uniqueKeysWithValues: Badge.allCases.enumerated().map { ($1, $0) })
        return Badge.allCases
            .filter { !earned.contains($0) }
            .sorted { lhs, rhs in
                let (left, right) = (lhs.fraction(facts), rhs.fraction(facts))
                if left != right { return left > right }
                if lhs.xp != rhs.xp { return lhs.xp < rhs.xp }
                return order[lhs, default: 0] < order[rhs, default: 0]
            }
            .prefix(limit)
            .map { $0 }
    }
}
