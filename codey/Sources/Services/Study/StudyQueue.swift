import Foundation

/// Card order for one study session. Pure value type (unit-tested).
///
/// Rating a card advances. "Again" also re-queues the card at the end, but
/// only once per session, so a hard card can't trap the learner in a loop.
/// Repeats are counted apart from the cards the session started with (S19),
/// so "2 / 4" never silently becomes "3 / 5": the counter says
/// "2 / 4 · +1 repeat", then "Repeat 1 of 1".
struct StudyQueue: Equatable {
    private(set) var cardIDs: [UUID]
    private(set) var position: Int
    private(set) var requeued: Set<UUID>

    init(cardIDs: [UUID], position: Int = 0, requeued: Set<UUID> = []) {
        self.cardIDs = cardIDs
        self.position = min(max(position, 0), cardIDs.count)
        self.requeued = requeued
    }

    var current: UUID? { position < cardIDs.count ? cardIDs[position] : nil }
    var isFinished: Bool { position >= cardIDs.count }
    /// Every card still to be shown or already shown, repeats included.
    var total: Int { cardIDs.count }
    /// Cards the session started with. Repeats are appended after them, so
    /// the first `distinctTotal` entries are the original cards.
    var distinctTotal: Int { Set(cardIDs).count }
    /// Cards added by "Again".
    var repeatCount: Int { total - distinctTotal }
    /// Whether the card on screen is a repeat.
    var isRepeat: Bool { !isFinished && position >= distinctTotal }
    /// 1-based index among the original cards, for "3 / 12". Stays at the
    /// last card while repeats play.
    var displayPosition: Int { min(position + 1, distinctTotal) }
    /// 1-based index of the repeat on screen, for "Repeat 1 of 2".
    var repeatPosition: Int { min(max(position - distinctTotal + 1, 0), repeatCount) }
    /// Fill for the bar beside "3 / 12": matches the counter, so the last
    /// card shows a full bar instead of "12 / 12" next to 11/12 filled.
    /// Repeats keep it full, so adding one never moves the bar back.
    var progress: Double {
        distinctTotal == 0 ? 1 : Double(displayPosition) / Double(distinctTotal)
    }

    /// Records a rating for the current card and moves on.
    mutating func record(_ rating: CardRating) {
        guard let id = current else { return }
        if rating == .again, !requeued.contains(id) {
            cardIDs.append(id)
            requeued.insert(id)
        }
        position += 1
    }

    /// Drops cards that no longer exist (deleted, or removed by a starter
    /// content update) when resuming, keeping the position on the same card.
    mutating func retain(only valid: Set<UUID>) {
        let removedBefore = cardIDs[..<position].filter { !valid.contains($0) }.count
        cardIDs.removeAll { !valid.contains($0) }
        requeued.formIntersection(valid)
        position = min(position - removedBefore, cardIDs.count)
    }
}
