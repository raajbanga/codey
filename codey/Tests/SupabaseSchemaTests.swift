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
        #expect(all.contains("avatar_id in (\(avatars))"))
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
}
