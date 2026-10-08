import Foundation
import Testing
@testable import codey

/// FR-23/24/28 rules on a single question.
struct QuestionProgressTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private func row() -> QuestionProgress {
        QuestionProgress(questionId: "q", topicId: "t", difficulty: .easy)
    }

    @Test func retiresAfterThreeCorrectInARow() {
        let progress = row()
        #expect(!progress.record(correct: true, at: t0))
        #expect(!progress.record(correct: true, at: t0))
        #expect(progress.record(correct: true, at: t0))
        #expect(progress.retiredAt == t0)
        #expect(progress.totalAttempts == 3 && progress.totalCorrect == 3)
    }

    @Test func wrongAnswerResetsTheStreak() {
        let progress = row()
        progress.record(correct: true, at: t0)
        progress.record(correct: true, at: t0)
        progress.record(correct: false, at: t0)
        #expect(progress.consecutiveCorrect == 0)
        progress.record(correct: true, at: t0)
        progress.record(correct: true, at: t0)
        #expect(!progress.isRetired)
        #expect(progress.record(correct: true, at: t0))
        #expect(progress.totalAttempts == 6 && progress.totalCorrect == 5)
    }

    @Test func returnsForReviewAfterSevenDays() {
        let progress = row()
        for _ in 0..<3 { progress.record(correct: true, at: t0) }

        #expect(!progress.returnForReviewIfDue(now: t0.addingTimeInterval(6.9 * 86_400)))
        #expect(progress.isRetired)
        #expect(progress.returnForReviewIfDue(now: t0.addingTimeInterval(7 * 86_400)))
        #expect(!progress.isRetired)
        #expect(progress.isReview)
        #expect(progress.consecutiveCorrect == 0)
    }

    @Test func reviewRetiresAgainOnOneCorrect() {
        let progress = row()
        for _ in 0..<3 { progress.record(correct: true, at: t0) }
        progress.returnForReviewIfDue(now: t0.addingTimeInterval(8 * 86_400))

        let later = t0.addingTimeInterval(9 * 86_400)
        #expect(progress.record(correct: true, at: later))
        #expect(progress.retiredAt == later)
        #expect(!progress.isReview)
    }

    @Test func wrongReviewStaysActiveAsANormalQuestion() {
        let progress = row()
        for _ in 0..<3 { progress.record(correct: true, at: t0) }
        progress.returnForReviewIfDue(now: t0.addingTimeInterval(8 * 86_400))

        #expect(!progress.record(correct: false, at: t0))
        #expect(!progress.isReview)
        #expect(!progress.isRetired)
        #expect(!progress.record(correct: true, at: t0), "back to needing 3 in a row")
    }

    @Test func activeQuestionsNeverReturnForReview() {
        let progress = row()
        #expect(!progress.returnForReviewIfDue(now: .distantFuture))
        #expect(!progress.isReview)
    }

    @Test func thresholdsComeFromConfig() {
        var config = GatingConfig()
        config.retireAfterConsecutiveCorrect = 1
        config.reviewAfterDays = 1
        let progress = row()
        #expect(progress.record(correct: true, at: t0, config: config))
        #expect(progress.returnForReviewIfDue(now: t0.addingTimeInterval(86_400), config: config))
    }

    @Test func stickyTopicUnlocks() {
        let topic = TopicProgress(topicId: "t")
        #expect(topic.unlockedTiers == [.easy])
        #expect(topic.unlock([.easy, .medium], at: t0) == [.medium])
        #expect(topic.unlock([.easy], at: t0.addingTimeInterval(5)).isEmpty, "never relocks")
        #expect(topic.unlockedTiers == [.easy, .medium])
        #expect(topic.mediumUnlockedAt == t0)
    }
}
