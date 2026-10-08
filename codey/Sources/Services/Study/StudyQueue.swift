import Foundation

/// Card order for one study session. Pure value type (unit-tested).
///
/// Rating a card advances. "Again" also re-queues the card at the end, but
/// only once per session, so a hard card can't trap the learner in a loop.
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
    var total: Int { cardIDs.count }
    /// 1-based index of the card on screen, for "3 / 12".
    var displayPosition: Int { min(position + 1, total) }
    var progress: Double { total == 0 ? 1 : Double(position) / Double(total) }

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
