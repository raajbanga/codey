import Foundation
import Testing
@testable import codey

/// Home's pure helpers: greeting, Up-next choice, topic ordering, deep-link routes.
struct HomeLogicTests {
    private func date(hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: hour))!
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test(arguments: [(5, "Good morning"), (11, "Good morning"), (12, "Good afternoon"), (16, "Good afternoon"), (17, "Good evening"), (2, "Good evening")])
    func greeting(hour: Int, expected: String) {
        #expect(HomeLogic.greeting(at: date(hour: hour), calendar: utc) == expected)
    }

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
    @Test func deckRouteSwitchesTabAndPushes() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertDeck(context)
        let router = Router()
        router.open(.deck(deck.id), context: context)
        #expect(router.tab == .decks)
        #expect(router.decksPath == [DeckRoute(id: deck.id)])
    }

    @Test func studyRouteResumesWhenASnapshotExists() throws {
        let context = try TestSupport.inMemoryContext()
        let deck = try TestSupport.insertTieredDeck(context, origin: .user, tiers: [nil, nil])
        let router = Router()

        router.open(.study(deck.id), context: context)
        #expect(router.study?.start == .fresh(tierFilter: nil))

        let vm = StudySessionViewModel(deck: deck, start: .fresh(tierFilter: nil), context: context)
        vm.toggleReveal()
        vm.rate(.good)
        router.open(.study(deck.id), context: context)
        #expect(router.study?.start == .resume)
    }

    @Test func unknownDeckDoesNothing() throws {
        let context = try TestSupport.inMemoryContext()
        let router = Router()
        router.open(.study(UUID()), context: context)
        #expect(router.study == nil)
    }

    @Test func quizRouteOpensSetupThenStartPresentsAfterDismiss() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 2, medium: 0, hard: 0)
        let router = Router()

        router.open(.quiz(topic.id), context: context)
        #expect(router.quizSetupTopic?.id == topic.id)

        router.startQuiz(QuizRequest(topic: topic, mode: .mixed))
        #expect(router.quizSetupTopic == nil)
        #expect(router.quiz == nil, "waits for the sheet to go away")
        router.presentPendingQuiz()
        #expect(router.quiz?.topic.id == topic.id)
    }

    @Test func startQuizWithoutASheetPresentsImmediately() throws {
        let context = try TestSupport.inMemoryContext()
        let topic = try TestSupport.insertTopic(context, easy: 2, medium: 0, hard: 0)
        let router = Router()
        router.startQuiz(QuizRequest(topic: topic, mode: .mixed))
        #expect(router.quiz != nil)
    }

    @Test func profileAndTabRoutes() throws {
        let context = try TestSupport.inMemoryContext()
        let router = Router()
        router.open(.profile, context: context)
        #expect(router.showProfile)
        router.open(.decks, context: context)
        #expect(router.tab == .decks)
        router.open(.home, context: context)
        #expect(router.tab == .home)
    }
}
