import Foundation
import SwiftData

/// Lets boot skip reseeding when the content hasn't changed. The stamp is a
/// hash of the content files seeded last (the Supabase download or the
/// bundle; ContentFiles.stamp), recorded after a full seed. Boot skips only when the stamp matches AND the rows are there, so a
/// new, reset, or in-memory store always seeds.
enum BundledContentStamp {
    static let defaultsKey = "codey.bundledContentStamp"

    /// SHA-256 of the bundled content, or nil if a file is missing (then
    /// boot seeds, and the loaders report the missing file).
    static func current(bundle: Bundle = .main) -> String? {
        ContentFiles.bundled(bundle)?.stamp
    }

    /// Whether `context` already holds the content `stamp` describes.
    static func isSeeded(_ stamp: String, context: ModelContext, defaults: UserDefaults = .standard) -> Bool {
        guard defaults.string(forKey: defaultsKey) == stamp else { return false }
        let starterRaw = DeckOrigin.starter.rawValue
        let topics = (try? context.fetchCount(FetchDescriptor<Topic>())) ?? 0
        let starterDecks = (try? context.fetchCount(FetchDescriptor<FlashcardDeck>(
            predicate: #Predicate { $0.originRaw == starterRaw }
        ))) ?? 0
        return topics >= QuestionBankLoader.expectedTopicCount && starterDecks >= StarterDeckLoader.expectedDeckCount
    }

    static func record(_ stamp: String, defaults: UserDefaults = .standard) {
        defaults.set(stamp, forKey: defaultsKey)
    }
}
