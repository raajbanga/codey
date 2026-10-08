/// Self-rating after revealing a card (FR-17), and its mastery rule (FR-18).
enum CardRating: String, Codable, CaseIterable {
    case again
    case hard
    case good
    case easy

    /// Mastery after this rating: again → 0, hard → unchanged, good → +1,
    /// easy → +2, clamped to 0...Flashcard.maxMastery.
    func applied(to score: Int) -> Int {
        let next: Int
        switch self {
        case .again: next = 0
        case .hard: next = score
        case .good: next = score + 1
        case .easy: next = score + 2
        }
        return min(max(next, 0), Flashcard.maxMastery)
    }
}
