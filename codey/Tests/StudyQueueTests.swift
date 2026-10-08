import Foundation
import Testing
@testable import codey

struct StudyQueueTests {
    private let a = UUID(), b = UUID(), c = UUID()

    @Test func goodRatingsWalkTheQueueAndFinish() {
        var queue = StudyQueue(cardIDs: [a, b])
        #expect(queue.current == a)
        #expect(queue.displayPosition == 1)
        queue.record(.good)
        #expect(queue.current == b)
        #expect(queue.progress == 0.5)
        queue.record(.easy)
        #expect(queue.isFinished)
        #expect(queue.current == nil)
        #expect(queue.displayPosition == 2)
        #expect(queue.progress == 1)
    }

    @Test func againRequeuesAtTheEndOnlyOnce() {
        var queue = StudyQueue(cardIDs: [a, b])
        queue.record(.again)
        #expect(queue.cardIDs == [a, b, a])
        queue.record(.hard)
        #expect(queue.current == a)
        queue.record(.again)
        #expect(queue.cardIDs == [a, b, a], "second Again doesn't requeue again")
        #expect(queue.isFinished)
    }

    @Test(arguments: [CardRating.hard, .good, .easy])
    func onlyAgainRequeues(rating: CardRating) {
        var queue = StudyQueue(cardIDs: [a])
        queue.record(rating)
        #expect(queue.isFinished)
        #expect(queue.total == 1)
    }

    @Test func recordingAfterFinishIsANoOp() {
        var queue = StudyQueue(cardIDs: [a])
        queue.record(.good)
        queue.record(.again)
        #expect(queue.position == 1)
        #expect(queue.cardIDs == [a])
    }

    @Test func emptyQueueIsFinished() {
        let queue = StudyQueue(cardIDs: [])
        #expect(queue.isFinished)
        #expect(queue.progress == 1)
        #expect(queue.displayPosition == 0)
    }

    @Test func retainDropsMissingCardsAndKeepsTheCurrentCard() {
        var queue = StudyQueue(cardIDs: [a, b, c], position: 2, requeued: [a])
        queue.retain(only: [b, c])
        #expect(queue.cardIDs == [b, c])
        #expect(queue.current == c)
        #expect(queue.requeued.isEmpty)
    }

    @Test func retainCanFinishTheQueue() {
        var queue = StudyQueue(cardIDs: [a, b], position: 1)
        queue.retain(only: [a])
        #expect(queue.isFinished)
    }

    @Test func positionIsClamped() {
        #expect(StudyQueue(cardIDs: [a], position: 9).position == 1)
        #expect(StudyQueue(cardIDs: [a], position: -1).position == 0)
    }
}

struct SwipeRatingTests {
    @Test(arguments: [
        (CGSize(width: 150, height: 10), CardRating?.some(.good)),
        (CGSize(width: -150, height: 10), .some(.again)),
        (CGSize(width: 20, height: -150), .some(.easy)),
        (CGSize(width: 50, height: -30), nil),
        (CGSize(width: 0, height: 150), nil),
    ])
    func swipeDirections(translation: CGSize, expected: CardRating?) {
        #expect(CardRating.forSwipe(translation, threshold: 110) == expected)
    }
}
