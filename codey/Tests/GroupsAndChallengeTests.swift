import Foundation
import SwiftData
import Testing
@testable import codey

/// S3-D: UTC weeks, the weekly challenge (FR-43), weekly XP (FR-42), board
/// ranking, invite codes, and the facade's group calls (FR-50–52).
@MainActor
struct GroupsAndChallengeTests {
    private func utc(_ text: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: text))
    }

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "codey-tests-\(UUID().uuidString)")!
    }

    // MARK: UTC week

    @Test func weekStartsMondayMidnightUTC() throws {
        let monday = try utc("2026-10-26T00:00:00Z")
        #expect(UTCWeek.start(of: try utc("2026-10-30T15:00:00Z")) == monday)
        #expect(UTCWeek.start(of: monday) == monday)
        // Sunday 23:59 UTC is still the previous week.
        #expect(UTCWeek.key(for: try utc("2026-10-25T23:59:00Z")) == "2026-10-19")
        #expect(UTCWeek.key(for: monday) == "2026-10-26")
    }

    @Test func weekStartAcrossTheYearBoundary() throws {
        // Fri 1 Jan 2027 is in the week of Mon 28 Dec 2026 (ISO week 53).
        let newYear = try utc("2027-01-01T12:00:00Z")
        #expect(UTCWeek.key(for: newYear) == "2026-12-28")
        #expect(UTCWeek.isoWeek(of: newYear) == 53)
        #expect(UTCWeek.isoWeek(of: try utc("2027-01-04T00:00:00Z")) == 1)
    }

    // MARK: Weekly challenge

    @Test func challengeTopicRotatesByISOWeek() throws {
        let topics = ["c", "a", "b"]  // sorted: a, b, c
        let week44 = try utc("2026-10-30T12:00:00Z")
        #expect(UTCWeek.isoWeek(of: week44) == 44)
        #expect(WeeklyChallenge.topicID(for: week44, topicIDs: topics) == "c")  // 44 % 3 = 2
        #expect(WeeklyChallenge.topicID(for: week44.addingTimeInterval(7 * 86_400), topicIDs: topics) == "a")
        #expect(WeeklyChallenge.topicID(for: week44, topicIDs: []) == nil)
    }

    @Test func challengeCountsCorrectAnswersInTheTopicThisWeek() throws {
        let now = try utc("2026-10-30T12:00:00Z")
        let topic = try #require(WeeklyChallenge.topicID(for: now, topicIDs: ["a", "b", "c"]))
        let thisWeek = try utc("2026-10-26T00:00:01Z")
        let lastWeek = try utc("2026-10-25T23:59:59Z")
        var answers: [(topicId: String, correct: Bool, answeredAt: Date)] = Array(repeating: (topic, true, thisWeek), count: 14)
        answers += [(topic, false, thisWeek), (topic, true, lastWeek), ("a", true, thisWeek)]

        let status = try #require(WeeklyChallenge.status(now: now, topicIDs: ["a", "b", "c"], answers: answers))
        #expect(status.correct == 14)
        #expect(!status.isComplete)

        answers.append((topic, true, now))
        let done = try #require(WeeklyChallenge.status(now: now, topicIDs: ["a", "b", "c"], answers: answers))
        #expect(done.isComplete)
        #expect(done.progress == 1)
    }

    @Test func completingTheChallengeEarnsTheBadge() throws {
        let context = try TestSupport.inMemoryContext()
        _ = try TestSupport.insertTopic(context, id: "only-topic", easy: 1, medium: 0, hard: 0)
        let now = Date.now
        for _ in 0..<WeeklyChallenge.goal {
            context.insert(QuizAnswerRecord(questionId: "q", topicId: "only-topic", correct: true, answeredAt: now))
        }
        try context.save()

        #expect(try BadgeEvaluator.facts(in: context, now: now).weeklyChallengesCompleted == 1)
        #expect(try BadgeEvaluator.award(context: context, now: now).contains(.weeklyChallenge))
    }

    // MARK: Weekly XP

    @Test func weeklyXPAccumulatesAndResetsWithTheWeek() throws {
        let store = WeeklyXPStore(defaults: isolatedDefaults())
        let friday = try utc("2026-10-30T12:00:00Z")
        store.add(15, now: friday)
        store.add(20, now: friday)
        store.add(0, now: friday)
        #expect(store.xp(now: friday) == 35)
        #expect(store.xp(now: try utc("2026-11-02T00:00:00Z")) == 0)

        store.add(10, now: try utc("2026-11-02T00:00:00Z"))
        #expect(store.xp(now: try utc("2026-11-03T00:00:00Z")) == 10)
    }

    @Test func weeklyXPIsCappedAtTheServerLimit() throws {
        let store = WeeklyXPStore(defaults: isolatedDefaults())
        store.add(WeeklyXPStore.cap - 5)
        store.add(45)
        #expect(store.xp() == WeeklyXPStore.cap)
    }

    @Test func syncPushesWeeklyXPOnlyWhenItChanged() async throws {
        let h = try SyncHarness()
        #expect(await h.engine.syncNow())
        #expect(!h.remote.requests.contains("upsertWeeklyXP"))  // 0 XP: nothing to push

        h.weeklyXP.add(30)
        #expect(await h.engine.syncNow())
        #expect(h.remote.weeklyXP[SyncHarness.alice.id] == 30)
        #expect(await h.engine.syncNow())
        #expect(h.remote.requests.filter { $0 == "upsertWeeklyXP" }.count == 1)

        h.weeklyXP.add(15)
        #expect(await h.engine.syncNow())
        #expect(h.remote.weeklyXP[SyncHarness.alice.id] == 45)
    }

    @Test func correctQuizAnswersAddWeeklyXP() throws {
        let context = try TestSupport.inMemoryContext()
        context.insert(UserProfile(username: "L", totalXP: 0))
        let topic = try TestSupport.insertTopic(context, easy: 5, medium: 0, hard: 0)
        let store = WeeklyXPStore(defaults: isolatedDefaults())
        let quiz = QuizViewModel(topic: topic, mode: .mixed, context: context, weeklyXP: store)
        let question = try #require(quiz.currentQuestion)

        quiz.select(question.correctOptionIndex)
        #expect(store.xp() == quiz.xpEarned)
        #expect(store.xp() > 0)
    }

    // MARK: Ranking

    @Test func tiesShareARankAndSortByName() {
        let me = UUID()
        let entries = [
            LeaderboardEntry(userId: UUID(), displayName: "Zed", avatarId: nil, xp: 120),
            LeaderboardEntry(userId: me, displayName: "Ana", avatarId: nil, xp: 120),
            LeaderboardEntry(userId: UUID(), displayName: "Bo", avatarId: nil, xp: 300),
            LeaderboardEntry(userId: UUID(), displayName: "Cy", avatarId: nil, xp: 0),
        ]
        let rows = LeaderboardRanking.rank(entries, me: me)
        #expect(rows.map(\.entry.displayName) == ["Bo", "Ana", "Zed", "Cy"])
        #expect(rows.map(\.rank) == [1, 2, 2, 4])
        #expect(rows.filter(\.isMe).map(\.entry.displayName) == ["Ana"])
    }

    // MARK: Validation

    @Test func groupNameAndInviteCodeRules() {
        #expect(ModelValidator.validateGroupName(String(repeating: "g", count: 40)).isEmpty)
        #expect(ModelValidator.validateGroupName(String(repeating: "g", count: 41)).first?.reason == .tooLong(max: 40, actual: 41))
        #expect(ModelValidator.validateGroupName("   ").first?.reason == .empty)

        #expect(ModelValidator.validateInviteCode("AB12CD").isEmpty)
        #expect(ModelValidator.validateInviteCode(" ab12cd ").isEmpty)
        #expect(ModelValidator.normalizedInviteCode(" ab12cd ") == "AB12CD")
        #expect(ModelValidator.validateInviteCode("AB12C").first?.reason == .invalidInviteCode)
        #expect(ModelValidator.validateInviteCode("AB12CD7").first?.reason == .invalidInviteCode)
        #expect(ModelValidator.validateInviteCode("AB-2CD").first?.reason == .invalidInviteCode)
        #expect(ModelValidator.validateInviteCode("ÀB12CD").first?.reason == .invalidInviteCode)
        #expect(ModelValidator.validateInviteCode("").first?.reason == .empty)
    }

    // MARK: Facade

    @Test func groupsNeedSignIn() async throws {
        let h = try SyncHarness(user: nil)
        await #expect(throws: GroupError.signInRequired) { try await h.facade.fetchGroups() }
        await #expect(throws: GroupError.signInRequired) { try await h.facade.createGroup(name: "Study buddies") }
        #expect(h.remote.requests.isEmpty)
    }

    @Test func createJoinAndLeave() async throws {
        let h = try SyncHarness()
        let group = try await h.facade.createGroup(name: "  CS 360  ")
        #expect(group.name == "CS 360")
        #expect(h.facade.cachedGroups?.groups == [group])

        // Joining by a lowercase code finds the same group.
        let joined = try await h.facade.joinGroup(code: group.inviteCode.lowercased())
        #expect(joined == group)

        try await h.facade.leaveGroup(group)
        #expect(h.facade.cachedGroups?.groups.isEmpty == true)
        #expect(try await h.facade.fetchGroups().isEmpty)
    }

    @Test func badInputIsRejectedBeforeAnyRequest() async throws {
        let h = try SyncHarness()
        await #expect(throws: FieldError.self) { try await h.facade.createGroup(name: String(repeating: "x", count: 41)) }
        await #expect(throws: FieldError.self) { try await h.facade.joinGroup(code: "ABC") }
        #expect(h.remote.requests.isEmpty)

        await #expect(throws: GroupError.invalidCode) { try await h.facade.joinGroup(code: "ZZZZZZ") }
    }

    @Test func leaderboardPushesYourXPFirstAndIsCached() async throws {
        let h = try SyncHarness()
        let group = try await h.facade.createGroup(name: "Board")
        let bob = UUID()
        h.remote.addMember(bob, name: "Bob", xp: 50, to: group.id)
        h.weeklyXP.add(80)

        let entries = try await h.facade.fetchLeaderboard(for: group.id)
        let rows = LeaderboardRanking.rank(entries, me: SyncHarness.alice.id)
        #expect(rows.map(\.entry.xp) == [80, 50])
        #expect(rows.first?.isMe == true)
        #expect(h.facade.cachedLeaderboard(for: group.id)?.entries == entries)

        // Offline: the call fails, the cached board stays.
        h.remote.isOffline = true
        await #expect(throws: (any Error).self) { try await h.facade.fetchLeaderboard(for: group.id) }
        #expect(h.facade.cachedLeaderboard(for: group.id)?.entries == entries)
    }

    /// Reads come from memory, writes still reach UserDefaults.
    @Test func groupCacheWritesThroughAndClears() throws {
        let defaults = try #require(UserDefaults(suiteName: "groupCache.\(UUID())"))
        let cache = GroupCache(defaults: defaults)
        let group = GroupSummary(id: UUID(), name: "Mine", inviteCode: "ABC123")
        cache.setGroups([group], at: .now)
        #expect(GroupCache(defaults: defaults).groups()?.groups == [group])
        cache.clear()
        #expect(cache.groups() == nil)
        #expect(GroupCache(defaults: defaults).groups() == nil)
    }

    @Test func signOutClearsTheGroupCache() async throws {
        let h = try SyncHarness()
        _ = try await h.facade.createGroup(name: "Mine")
        await h.facade.signOut(removingLocalDecks: false)
        #expect(h.facade.cachedGroups == nil)
    }
}
