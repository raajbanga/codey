import Foundation
import Testing
@testable import codey

/// Home's pure helpers: Up-next choice, topic ordering, deep-link routes.
struct HomeLogicTests {
    @Test func upNextPriority() {
        let deck = UUID(), starter = UUID()
        let resume = (deckID: deck, position: 3, total: 10)
        #expect(HomeLogic.upNext(resumable: resume, isNewLearner: true, starterDeckID: starter, weakestTopicID: "t")
            == .resume(deckID: deck, position: 3, total: 10))
        #expect(HomeLogic.upNext(resumable: nil, isNewLearner: true, starterDeckID: starter, weakestTopicID: "t")
            == .startDeck(deckID: starter))
        #expect(HomeLogic.upNext(resumable: nil, isNewLearner: false, starterDeckID: starter, weakestTopicID: "t")
            == .quiz(topicID: "t"))
        #expect(HomeLogic.upNext(resumable: nil, isNewLearner: true, starterDeckID: nil, weakestTopicID: "t")
            == .quiz(topicID: "t"))
        #expect(HomeLogic.upNext(resumable: nil, isNewLearner: false, starterDeckID: nil, weakestTopicID: nil) == .none)
    }

    @Test func everyTopicShowsWithPinnedFirst() {
        let all = [("a", "Algorithms"), ("d", "Databases"), ("o", "OS"), ("s", "Data Structures")]
        let ids = HomeLogic.orderedTopicIDs(all: all.map { (id: $0.0, title: $0.1) }, pinned: ["o", "a", "gone"])
        #expect(ids == ["o", "a", "s", "d"])
        #expect(HomeLogic.orderedTopicIDs(all: all.map { (id: $0.0, title: $0.1) }, pinned: []) == ["a", "s", "d", "o"])
    }

    @Test func weakestTopicPrefersUntriedThenLowestAccuracy() {
        #expect(HomeLogic.weakestTopicID(candidates: ["a", "b", "c"], accuracy: ["a": 0.9, "b": 0.4, "c": 0.6]) == "b")
        #expect(HomeLogic.weakestTopicID(candidates: ["a", "b"], accuracy: ["a": 0.2]) == "b", "untried = 0%")
        #expect(HomeLogic.weakestTopicID(candidates: ["a", "b"], accuracy: [:]) == "a", "ties keep order")
        #expect(HomeLogic.weakestTopicID(candidates: [], accuracy: [:]) == nil)
    }
}

@MainActor
struct RouterTests {
    @Test func startFromTheSetupPanelClosesItAndPresents() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 2, medium: 0, hard: 0)
        let router = Router()

        router.quizSetupTopic = topic
        router.startQuiz(QuizRequest(topic: topic, mode: .mixed))
        #expect(router.quizSetupTopic == nil)
        #expect(router.quiz?.topic.id == topic.id)
    }

    @Test func startQuizWithoutASheetPresentsImmediately() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 2, medium: 0, hard: 0)
        let router = Router()
        router.startQuiz(QuizRequest(topic: topic, mode: .mixed))
        #expect(router.quiz != nil)
    }
}

/// HomeStats: the once-per-render derivations behind Home.
@MainActor
struct HomeStatsTests {
    @Test func accuracyMatchesTheStoreOverTheNewestWindow() throws {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        // Topic "a": 10 old wrong, then 50 right; topic "b": 3 answers, 1 right.
        var records = (0..<60).map { n in
            QuizAnswerRecord(questionId: "q", topicId: "a", correct: n >= 10, answeredAt: t0.addingTimeInterval(Double(n)))
        }
        records += (0..<3).map { n in
            QuizAnswerRecord(questionId: "q", topicId: "b", correct: n == 0, answeredAt: t0.addingTimeInterval(Double(n)))
        }
        records.sort { $0.answeredAt > $1.answeredAt }

        let stats = HomeStats(records: records, decks: [], snapshots: [], window: 50)
        #expect(stats.accuracyByTopic["a"] == QuizProgressStore.accuracy(of: records.filter { $0.topicId == "a" }, window: 50))
        #expect(stats.accuracyByTopic["a"] == 1.0)
        #expect(stats.accuracyByTopic["b"] == 1.0 / 3.0)
        #expect(stats.answerCounts == ["a": 50, "b": 3])
    }

    @Test func decksAreGroupedStarterFirstAndSkipHiddenOrEmpty() throws {
        let context = try TestSupport.inMemoryContext()
        let user = try TestSupport.insertDeck(context, title: "A mine", origin: .user)
        let starter = try TestSupport.insertDeck(context, title: "Z starter", origin: .starter)
        let hidden = try TestSupport.insertDeck(context, title: "Hidden", origin: .starter)
        hidden.isHidden = true
        let empty = try TestSupport.insertDeck(context, title: "Empty", prompts: [])

        let stats = HomeStats(records: [], decks: [user, starter, hidden, empty], snapshots: [])
        #expect(stats.decksByTopic["topic-data-structures"]?.map(\.title) == ["Z starter", "A mine"])
        #expect(stats.deckByID.count == 4)
    }
}
