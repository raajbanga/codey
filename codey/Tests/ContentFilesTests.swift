import Foundation
import Testing
@testable import codey

/// The content files: the bundle passes the loaders, and a download is
/// cached whole and read back as it was written.
struct ContentFilesTests {
    @Test func bundledContentValidates() throws {
        let content = try #require(ContentFiles.bundled()).validated()
        #expect(content.bank.topics.count == QuestionBankLoader.expectedTopicCount)
        #expect(content.bank.questions.count == QuestionBankLoader.expectedQuestionCount)
        #expect(content.decks.decks.count == StarterDeckLoader.expectedDeckCount)
        #expect(!content.exercises.isEmpty)
    }

    @Test func cacheRoundTripsAndNeedsAllThreeFiles() throws {
        let directory = URL.temporaryDirectory.appending(path: "ContentFilesTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(ContentFiles.cached(in: directory) == nil)

        let files = try #require(ContentFiles.bundled())
        try files.write(to: directory)
        #expect(ContentFiles.cached(in: directory) == files)
        #expect(ContentFiles.cached(in: directory)?.stamp == files.stamp)

        try FileManager.default.removeItem(at: directory.appending(path: "exercises.json"))
        #expect(ContentFiles.cached(in: directory) == nil, "a partial cache falls back to the bundle")
    }

    @Test func stampChangesWithAnyFile() throws {
        let files = try #require(ContentFiles.bundled())
        var changed = files
        changed.exercises.append(contentsOf: Data(" ".utf8))
        #expect(changed.stamp != files.stamp)
    }

    @Test func invalidDownloadIsRejected() throws {
        var files = try #require(ContentFiles.bundled())
        files.exercises = Data(#"{"schemaVersion":1,"exercises":[]}"#.utf8)
        #expect(throws: ExerciseLoaderError.empty) { try files.validated() }
    }
}
