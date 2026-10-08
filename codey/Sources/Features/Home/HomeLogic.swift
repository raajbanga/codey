import Foundation

/// Pure helpers behind HomeView (unit-tested).
enum HomeLogic {
    /// "Good morning" before noon, "Good afternoon" until 5 pm, else evening.
    static func greeting(at date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
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

    /// The single suggestion on Home's "Up next" card.
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
