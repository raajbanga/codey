import Foundation
import SwiftData
import Testing
@testable import codey

/// FR-61 study progress sync against the mock backend (no network): the
/// merge rules, push/pull through SyncEngine, offline retry, and two devices
/// converging.
@MainActor
struct ProgressSyncTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func card(_ h: SyncHarness) throws -> Flashcard {
        let deck = try h.saveNewDeck(prompts: ["Q1"])
        return try #require(deck.cards.first)
    }

    // MARK: Merge rules

    @Test func remoteWinsOnlyWhenStrictlyNewer() {
        #expect(ProgressSync.remoteWins(t0, over: nil))
        #expect(ProgressSync.remoteWins(t0.addingTimeInterval(1), over: t0))
        #expect(!ProgressSync.remoteWins(t0, over: t0))
        #expect(!ProgressSync.remoteWins(t0, over: t0.addingTimeInterval(1)))
    }

    @Test func unlocksKeepTheEarliestNonNilDate() {
        #expect(ProgressSync.earliest(nil, nil) == nil)
        #expect(ProgressSync.earliest(t0, nil) == t0)
        #expect(ProgressSync.earliest(nil, t0) == t0)
        #expect(ProgressSync.earliest(t0.addingTimeInterval(5), t0) == t0)
    }

    // MARK: Push

    @Test func ratedCardIsPushedOnceThenNotAgain() async throws {
        let h = try SyncHarness()
        let card = try card(h)
        card.updateMastery(rating: .good, at: Date())
        try h.context.save()

        #expect(await h.engine.syncNow())
        #expect(h.remote.cardProgress[card.id]?.masteryScore == 1)

        let pushes = h.remote.pushedProgress.count
        #expect(await h.engine.syncNow())
        #expect(h.remote.pushedProgress.count == pushes, "nothing changed, so nothing is pushed")
    }

    @Test func unreviewedCardsAreNotPushed() async throws {
        let h = try SyncHarness()
        _ = try card(h)
        #expect(await h.engine.syncNow())
        #expect(h.remote.cardProgress.isEmpty)
    }

    @Test func quizAnswerAndUnlockArePushed() async throws {
        let h = try SyncHarness()
        let question = QuestionProgress(questionId: "q-1", topicId: "topic-swift", difficulty: .easy)
        question.record(correct: true, at: Date())
        let topic = TopicProgress(topicId: "topic-swift")
        topic.unlock([.medium], at: Date())
        h.context.insert(question)
        h.context.insert(topic)
        try h.context.save()

        #expect(await h.engine.syncNow())
        #expect(h.remote.questionProgress["q-1"]?.totalCorrect == 1)
        #expect(h.remote.topicProgress["topic-swift"]?.mediumUnlockedAt != nil)
    }

    // MARK: Pull

    @Test func newerRemoteReviewWinsEvenWhenItLowersMastery() async throws {
        let h = try SyncHarness()
        let card = try card(h)
        card.updateMastery(rating: .easy, at: t0)
        try h.context.save()
        #expect(await h.engine.syncNow())

        let later = t0.addingTimeInterval(60)
        h.remote.otherDeviceUpsert(progress: ProgressBatch(cards: [
            CardProgressPayload(cardId: card.id, masteryScore: 0, lastReviewedAt: later, retiredAt: nil),
        ]))
        #expect(await h.engine.syncNow())
        #expect(card.masteryScore == 0)
        #expect(card.lastReviewedAt == later)
    }

    @Test func olderRemoteReviewDoesNotOverwriteLocal() async throws {
        let h = try SyncHarness()
        let card = try card(h)
        h.remote.otherDeviceUpsert(progress: ProgressBatch(cards: [
            CardProgressPayload(cardId: card.id, masteryScore: 5, lastReviewedAt: t0, retiredAt: t0),
        ]))
        card.updateMastery(rating: .good, at: t0.addingTimeInterval(60))
        try h.context.save()

        #expect(await h.engine.syncNow())
        #expect(card.masteryScore == 1, "local review is newer")
        #expect(h.remote.cardProgress[card.id]?.masteryScore == 1, "and it replaced the older remote row")
    }

    @Test func pulledQuestionProgressCreatesTheLocalRow() async throws {
        let h = try SyncHarness()
        h.remote.otherDeviceUpsert(progress: ProgressBatch(questions: [
            QuestionProgressPayload(questionId: "q-9", topicId: "topic-swift", difficulty: .hard,
                                    consecutiveCorrect: 2, totalAttempts: 4, totalCorrect: 3,
                                    retiredAt: nil, isReview: false, lastAnsweredAt: t0),
        ]))
        #expect(await h.engine.syncNow())

        let rows = try h.context.fetch(FetchDescriptor<QuestionProgress>())
        #expect(rows.count == 1)
        #expect(rows.first?.questionId == "q-9")
        #expect(rows.first?.totalAttempts == 4)
        #expect(rows.first?.difficulty == .hard)
    }

    @Test func pulledUnlocksAreStickyAndNeverRelock() async throws {
        let h = try SyncHarness()
        let topic = TopicProgress(topicId: "topic-swift")
        topic.unlock([.medium], at: t0)
        h.context.insert(topic)
        try h.context.save()

        h.remote.otherDeviceUpsert(progress: ProgressBatch(topics: [
            TopicProgressPayload(topicId: "topic-swift", mediumUnlockedAt: nil, hardUnlockedAt: t0.addingTimeInterval(9)),
        ]))
        #expect(await h.engine.syncNow())
        #expect(topic.mediumUnlockedAt == t0, "a remote nil doesn't relock Medium")
        #expect(topic.hardUnlockedAt == t0.addingTimeInterval(9), "Hard unlocked on the other device")
        #expect(h.remote.topicProgress["topic-swift"]?.mediumUnlockedAt == t0, "server gains the local unlock")
    }

    @Test func progressForAnUnknownCardIsSkipped() async throws {
        let h = try SyncHarness()
        h.remote.otherDeviceUpsert(progress: ProgressBatch(cards: [
            CardProgressPayload(cardId: UUID(), masteryScore: 3, lastReviewedAt: t0, retiredAt: nil),
        ]))
        #expect(await h.engine.syncNow())
    }

    // MARK: Offline

    @Test func offlinePushIsRetriedAfterReconnect() async throws {
        let h = try SyncHarness()
        let card = try card(h)
        #expect(await h.engine.syncNow())

        card.updateMastery(rating: .good, at: Date())
        try h.context.save()
        h.remote.isOffline = true
        #expect(await !h.engine.syncNow())
        #expect(h.remote.cardProgress[card.id] == nil)

        h.remote.isOffline = false
        #expect(await h.engine.syncNow())
        #expect(h.remote.cardProgress[card.id]?.masteryScore == 1)
    }

    // MARK: Two devices

    @Test func twoDevicesConvergeOnTheLatestReview() async throws {
        let server = MockRemoteStore()
        let phone = try SyncHarness(remote: server)
        let deck = try phone.saveNewDeck(prompts: ["Q1"])
        let phoneCard = try #require(deck.cards.first)
        #expect(await phone.engine.syncNow())

        let tablet = try SyncHarness(remote: server)
        #expect(await tablet.engine.syncNow())
        let tabletCard = try #require(try tablet.context.fetch(FetchDescriptor<Flashcard>()).first { $0.id == phoneCard.id })

        phoneCard.updateMastery(rating: .easy, at: t0)
        try phone.context.save()
        #expect(await phone.engine.syncNow())

        tabletCard.updateMastery(rating: .again, at: t0.addingTimeInterval(30))
        try tablet.context.save()
        #expect(await tablet.engine.syncNow())
        #expect(await phone.engine.syncNow())

        #expect(phoneCard.masteryScore == 0)
        #expect(tabletCard.masteryScore == 0)
        #expect(server.cardProgress[phoneCard.id]?.lastReviewedAt == t0.addingTimeInterval(30))
    }

    // MARK: Sign-out

    @Test func signOutResetsTheProgressMarkersSoTheNextSignInPushesEverything() async throws {
        let h = try SyncHarness()
        let card = try card(h)
        card.updateMastery(rating: .good, at: Date())
        try h.context.save()
        #expect(await h.engine.syncNow())
        let pushedBefore = h.remote.pushedProgress.count

        await h.facade.signOut(removingLocalDecks: false)
        h.auth.user = SyncHarness.alice
        #expect(await h.engine.syncNow())
        // Everything pulled back is an echo, so nothing new goes up.
        #expect(h.remote.pushedProgress.count == pushedBefore)
        #expect(card.masteryScore == 1)
    }
}
