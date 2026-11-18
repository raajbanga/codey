import Foundation
import Testing
@testable import codey

/// S45 coding challenges (FR-69 to FR-74): the bundled file is valid, a bad
/// file is rejected whole, drafts survive per language, results print like
/// the runner's JSON, and a solve pays XP once.
@MainActor
struct ChallengeTests {
    private let topics: Set = ["topic-algorithms"]

    /// A minimal valid challenge, as JSON, with one field overridden.
    private func file(_ challenges: [[String: Any]], schemaVersion: Int = 1) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schemaVersion": schemaVersion, "challenges": challenges])
    }

    private func challenge(_ overrides: [String: Any] = [:]) -> [String: Any] {
        var base: [String: Any] = [
            "id": "ch-two-sum", "topicId": "topic-algorithms", "title": "Two Sum",
            "difficulty": "easy", "statement": "Find two indices.", "constraints": [String](),
            "hints": ["Use a dictionary."], "functionName": "twoSum",
            "params": [["name": "nums", "type": "int[]"]], "returnType": "int[]",
            "comparator": "exact", "editorial": "One pass.",
            "starters": ["python": "def twoSum(nums):\n    pass\n"],
            "examples": [["input": "nums = [2,7]", "output": "[0,1]"]],
        ]
        base.merge(overrides) { _, new in new }
        return base
    }

    // MARK: Loader

    @Test func bundledChallengesValidateWithTheContent() throws {
        let content = try #require(ContentFiles.bundled()).validated()
        #expect(!content.challenges.isEmpty)
        #expect(Set(content.challenges.map(\.id)).count == content.challenges.count)
        for challenge in content.challenges {
            #expect(!challenge.languages.isEmpty, "\(challenge.id)")
            #expect(!challenge.examples.isEmpty, "\(challenge.id)")
            #expect((1...3).contains(challenge.hints.count), "\(challenge.id): hints")
        }
    }

    @Test func emptyDataMeansNoChallenges() throws {
        #expect(try ChallengeLoader.decode(Data(), topicIds: topics).isEmpty)
    }

    @Test func validFileDecodes() throws {
        let decoded = try ChallengeLoader.decode(try file([challenge()]), topicIds: topics)
        #expect(decoded.map(\.id) == ["ch-two-sum"])
        #expect(decoded[0].languages == [.python])
        #expect(decoded[0].starter(for: .swift).isEmpty)
    }

    @Test func badFilesAreRejected() throws {
        let cases: [([[String: Any]], ChallengeLoaderError)] = [
            ([challenge(["id": "two-sum"])], .badId("two-sum")),
            ([challenge(), challenge()], .duplicateId("ch-two-sum")),
            ([challenge(["topicId": "topic-nope"])], .unknownTopicId(challengeId: "ch-two-sum", topicId: "topic-nope")),
            ([challenge(["starters": [String: String]()])], .missingStarter(challengeId: "ch-two-sum")),
            ([challenge(["examples": [[String: String]]()])], .noExamples(challengeId: "ch-two-sum")),
            ([challenge(["hints": ["a", "b", "c", "d"]])], .tooManyHints(challengeId: "ch-two-sum")),
        ]
        for (challenges, expected) in cases {
            #expect(throws: expected) { try ChallengeLoader.decode(try file(challenges), topicIds: topics) }
        }
        #expect(throws: ChallengeLoaderError.unsupportedSchemaVersion(2)) {
            try ChallengeLoader.decode(try file([challenge()], schemaVersion: 2), topicIds: topics)
        }
    }

    // MARK: Catalog

    @Test func nextPrefersUnsolvedAndWraps() throws {
        let all = try ChallengeLoader.decode(
            try file(["ch-a", "ch-b", "ch-c"].map { challenge(["id": $0]) }),
            topicIds: topics
        )
        let catalog = ChallengeCatalog()
        catalog.replace(with: all)
        #expect(catalog.next(after: all[0], solved: [])?.id == "ch-b")
        #expect(catalog.next(after: all[0], solved: ["ch-b"])?.id == "ch-c")
        #expect(catalog.next(after: all[2], solved: [])?.id == "ch-a", "wraps to the start")
        #expect(catalog.next(after: all[0], solved: ["ch-b", "ch-c"])?.id == "ch-b", "all solved: the next one anyway")
    }

    // MARK: Drafts (FR-73)

    @Test func draftsAreKeptPerChallengeAndLanguage() {
        let directory = URL.temporaryDirectory.appending(path: "ChallengeDrafts-\(UUID().uuidString)")
        defer { ChallengeDrafts.removeAll(in: directory) }
        #expect(ChallengeDrafts.load("ch-a", language: .python, in: directory) == nil)

        ChallengeDrafts.save("print(1)", id: "ch-a", language: .python, in: directory)
        ChallengeDrafts.save("print(2)", id: "ch-a", language: .swift, in: directory)
        #expect(ChallengeDrafts.load("ch-a", language: .python, in: directory) == "print(1)")
        #expect(ChallengeDrafts.load("ch-a", language: .swift, in: directory) == "print(2)")
        #expect(ChallengeDrafts.load("ch-b", language: .python, in: directory) == nil)

        ChallengeDrafts.remove("ch-a", language: .python, in: directory)
        #expect(ChallengeDrafts.load("ch-a", language: .python, in: directory) == nil)
        #expect(ChallengeDrafts.load("ch-a", language: .swift, in: directory) == "print(2)")

        ChallengeDrafts.removeAll(in: directory)
        #expect(ChallengeDrafts.load("ch-a", language: .swift, in: directory) == nil)
    }

    // MARK: Results

    @Test func jsonValuesPrintCompactly() throws {
        let value = try JSONDecoder().decode(
            JSONValue.self,
            from: Data(#"[1, 2.5, "a/b", true, null, {"b": [], "a": 0}]"#.utf8)
        )
        #expect(value.description == #"[1,2.5,"a/b",true,null,{"a":0,"b":[]}]"#)
    }

    // MARK: XP (S41 rules)

    @Test(arguments: [(Difficulty.easy, 20), (.medium, 35), (.hard, 50)])
    func rewardGrowsWithTier(difficulty: Difficulty, expected: Int) {
        #expect(XPRewards.challengeReward(difficulty) == expected)
    }

    @Test func solvePaysOnce() {
        let profile = UserProfile(username: "x")
        let weekly = WeeklyXPStore(defaults: UserDefaults(suiteName: "codey-ch-\(UUID().uuidString)")!)
        let first = XPRewards.solveChallenge(id: "ch-a", difficulty: .medium, profile: profile, weeklyXP: weekly, now: .now)
        let again = XPRewards.solveChallenge(id: "ch-a", difficulty: .medium, profile: profile, weeklyXP: weekly, now: .now)
        #expect(first == 35)
        #expect(again == 0)
        #expect(profile.totalXP == 35)
        #expect(profile.solvedExerciseIds == ["ch-a"])
    }
}
