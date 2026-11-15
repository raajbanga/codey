import Foundation
import Testing
@testable import codey

/// The SQL migrations (supabase/migrations) must enforce the same limits as
/// ModelValidator, or a card that saves locally would be rejected by the
/// server. Reads the files from the repo via #filePath (dev machine / CI).
struct SupabaseSchemaTests {
    private static let migrationsURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // codey
        .deletingLastPathComponent() // repo root
        .appending(path: "supabase/migrations", directoryHint: .isDirectory)

    private func migrations() throws -> [(name: String, sql: String)] {
        let files = try FileManager.default.contentsOfDirectory(at: Self.migrationsURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "sql" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    private func decksSQL() throws -> String {
        try #require(try migrations().first { $0.name.hasSuffix("_decks_flashcards.sql") }?.sql)
    }

    @Test func textLimitsMatchValidator() throws {
        let sql = try decksSQL()
        let limits = ModelValidator.Limits.self
        let trimmed = "E' \\t\\r\\n')) between"
        #expect(sql.contains("btrim(title, \(trimmed) \(limits.deckTitle.lowerBound) and \(limits.deckTitle.upperBound)"))
        #expect(sql.contains("btrim(prompt, \(trimmed) \(limits.prompt.lowerBound) and \(limits.prompt.upperBound)"))
        #expect(sql.contains("btrim(answer, \(trimmed) \(limits.answer.lowerBound) and \(limits.answer.upperBound)"))
        #expect(sql.contains("btrim(code_source, \(trimmed) \(limits.snippetSource.lowerBound) and \(limits.snippetSource.upperBound)"))
        #expect(sql.contains("E'\\n'), 1) <= \(limits.snippetMaxLines)"))
    }

    @Test func enumsMatchSwiftTypes() throws {
        let sql = try decksSQL()
        let languages = CodeLanguage.allCases.map { "'\($0.rawValue)'" }.joined(separator: ", ")
        let tiers = Difficulty.allCases.map { "'\($0.rawValue)'" }.joined(separator: ", ")
        #expect(sql.contains("code_language in (\(languages))"))
        #expect(sql.contains("difficulty in (\(tiers))"))
    }

    /// FR-04 / FR-49 (S3-C): the profile and report limits match the app.
    @Test func profileAndFeedbackLimitsMatchValidator() throws {
        let all = try migrations().map(\.sql).joined(separator: "\n")
        let limits = ModelValidator.Limits.self
        #expect(all.contains("between \(limits.displayName.lowerBound) and \(limits.displayName.upperBound)"))
        #expect(all.contains("btrim(description, E' \\t\\r\\n')) between \(limits.feedback.lowerBound) and \(limits.feedback.upperBound)"))
        let avatars = ProfileAvatar.symbols.map { "'\($0)'" }.joined(separator: ", ")
        #expect(all.contains("split_part(avatar_id, '@', 1) in (\(avatars))"))
        let colors = ProfileAvatar.Color.allCases.map { "'\($0.rawValue)'" }.joined(separator: ", ")
        #expect(all.contains("split_part(avatar_id, '@', 2) in (\(colors))"))
    }

    /// FR-42 / FR-50–51 (S3-D): group and weekly XP limits match the app.
    @Test func groupLimitsMatchApp() throws {
        let all = try migrations().map(\.sql).joined(separator: "\n")
        let limits = ModelValidator.Limits.self
        #expect(all.contains("btrim(name, E' \\t\\r\\n')) between \(limits.groupName.lowerBound) and \(limits.groupName.upperBound)"))
        #expect(all.contains("invite_code ~ '^[A-Z0-9]{\(limits.inviteCodeLength)}$'"))
        #expect(all.contains("xp between 0 and \(WeeklyXPStore.cap)"))
    }

    /// NFR-07: every table created by a migration has RLS enabled.
    @Test func everyTableHasRowLevelSecurity() throws {
        let all = try migrations().map(\.sql).joined(separator: "\n")
        let created = all.matches(of: #/create table public\.(\w+)/#).map { String($0.1) }
        #expect(!created.isEmpty)
        for table in created {
            let enabled = try Regex("alter table public\\.\(table)\\s+enable row level security")
            #expect(all.contains(enabled), "\(table) has no RLS")
        }
    }

    /// FR-61: progress limits match the app, and every bundled question and
    /// topic id fits the 100-character id columns.
    @Test func progressLimitsMatchApp() throws {
        let sql = try #require(try migrations().first { $0.name.hasSuffix("_study_progress.sql") }?.sql)
        #expect(sql.contains("mastery_score     integer not null check (mastery_score between 0 and \(Flashcard.maxMastery))"))
        let tiers = Difficulty.allCases.map { "'\($0.rawValue)'" }.joined(separator: ", ")
        #expect(sql.contains("difficulty in (\(tiers))"))
        #expect(sql.contains("char_length(question_id) between 1 and 100"))
        #expect(sql.contains("char_length(topic_id) between 1 and 100"))

        let url = try #require(Bundle.main.url(forResource: "questions-seed", withExtension: "json"))
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        var ids: [String] = []
        func collect(_ value: Any) {
            if let object = value as? [String: Any] {
                if let id = object["id"] as? String { ids.append(id) }
                object.values.forEach(collect)
            } else if let array = value as? [Any] {
                array.forEach(collect)
            }
        }
        collect(json)
        #expect(!ids.isEmpty)
        #expect(ids.allSatisfy { (1...100).contains($0.count) })
    }
}
