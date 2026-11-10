import Foundation
import SwiftData
import os

/// starter-decks.json, as decoded (FR-14, D3).
struct StarterDeckFile: Decodable, Equatable {
    let schemaVersion: Int
    let decks: [StarterDeckSeed]
}

struct StarterDeckSeed: Decodable, Equatable {
    let starterKey: String
    let topicId: String
    let title: String
    let cards: [StarterCardSeed]
}

struct StarterCardSeed: Decodable, Equatable {
    struct Code: Decodable, Equatable {
        let language: String
        let source: String
    }

    let id: String
    let prompt: String
    let answer: String
    let difficulty: Difficulty
    /// Optional per card.
    let code: Code?

    /// The wire DTO the factory consumes; id is the stable UUID of `id`.
    func payload(sortIndex: Int) -> FlashcardPayload {
        FlashcardPayload(
            id: StableID.uuid(id),
            prompt: prompt,
            answer: answer,
            codeLanguage: code?.language,
            codeSource: code?.source,
            difficulty: difficulty,
            sortIndex: sortIndex
        )
    }
}

enum StarterDeckLoaderError: Error, LocalizedError, Equatable {
    case fileNotFound
    case unsupportedSchemaVersion(Int)
    case duplicateKey(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound: "starter-decks.json not found in bundle"
        case .unsupportedSchemaVersion(let version): "Unsupported starter deck schema version: \(version)"
        case .duplicateKey(let key): "Duplicate starter deck/card key: \(key)"
        }
    }
}

// MARK: - [Pattern: Factory] Client (starter decks)
/// Puts the bundled starter decks into the store, using the same rules as
/// DataSeeder (Stage 0): upsert by stable id, never touch user data.
///
/// - Every card goes through FlashcardFactory (factory rule: "including
///   starter decks").
/// - A text change updates the card in place, so mastery, retiredAt, and the
///   deck's isHidden are preserved.
/// - Cards/decks removed from the JSON are deleted (starter decks never
///   sync, so no tombstones are needed).
/// - Starter decks are origin = .starter, never editable, never pushed.
enum StarterDeckLoader {
    static let expectedSchemaVersion = 1
    static let expectedDeckCount = 12
    private static let fileName = "starter-decks"

    static func loadBundle(from bundle: Bundle = .main) throws -> StarterDeckFile {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw StarterDeckLoaderError.fileNotFound
        }
        let file = try JSONDecoder().decode(StarterDeckFile.self, from: Data(contentsOf: url))
        guard file.schemaVersion == expectedSchemaVersion else {
            throw StarterDeckLoaderError.unsupportedSchemaVersion(file.schemaVersion)
        }
        var seen = Set<String>()
        for key in file.decks.map(\.starterKey) + file.decks.flatMap({ $0.cards.map(\.id) }) {
            guard seen.insert(key).inserted else { throw StarterDeckLoaderError.duplicateKey(key) }
        }
        return file
    }

    /// Loads the bundle and upserts it. Boot-time entry point.
    @discardableResult
    static func seed(context: ModelContext) throws -> DataSeeder.Report {
        try seed(context: context, file: loadBundle())
    }

    @discardableResult
    static func seed(context: ModelContext, file: StarterDeckFile, factory: FlashcardFactory = FlashcardFactory()) throws -> DataSeeder.Report {
        // A truncated bundle must not read as "these decks were removed".
        guard file.decks.count >= expectedDeckCount else {
            Logger.seeding.error("Starter bundle has \(file.decks.count) decks; expected \(expectedDeckCount). Skipping.")
            return DataSeeder.Report()
        }

        let knownTopics = Set(try context.fetch(FetchDescriptor<Topic>()).map(\.id))
        let starterRaw = DeckOrigin.starter.rawValue
        let existing = try context.fetch(FetchDescriptor<FlashcardDeck>(predicate: #Predicate { $0.originRaw == starterRaw }))
            .filter { $0.starterKey != nil }
            .keyed { $0.starterKey ?? "" }

        var report = DataSeeder.Report()
        for seed in file.decks {
            guard knownTopics.contains(seed.topicId) else {
                Logger.seeding.error("Starter deck \(seed.starterKey, privacy: .public) has unknown topic; skipped")
                continue
            }
            let deck: FlashcardDeck
            if let found = existing[seed.starterKey] {
                deck = found
                if deck.title != seed.title || deck.topicId != seed.topicId {
                    deck.title = seed.title
                    deck.topicId = seed.topicId
                    report.updated += 1
                }
            } else {
                deck = FlashcardDeck(
                    id: StableID.uuid(seed.starterKey),
                    title: seed.title,
                    topicId: seed.topicId,
                    origin: .starter,
                    starterKey: seed.starterKey,
                    syncState: .locallyPersisted
                )
                context.insert(deck)
                report.inserted += 1
            }
            upsertCards(seed.cards, into: deck, context: context, factory: factory, report: &report)
        }

        let bundledKeys = Set(file.decks.map(\.starterKey))
        for (key, deck) in existing where !bundledKeys.contains(key) {
            context.delete(deck)
            report.deleted += 1
        }

        if context.hasChanges {
            try context.save()
        }
        Logger.seeding.info("Starter decks: +\(report.inserted) ~\(report.updated) -\(report.deleted)")
        return report
    }

    private static func upsertCards(
        _ seeds: [StarterCardSeed],
        into deck: FlashcardDeck,
        context: ModelContext,
        factory: FlashcardFactory,
        report: inout DataSeeder.Report
    ) {
        let existing = deck.cards.keyed(by: \.id)
        var kept = Set<UUID>()

        for (index, seed) in seeds.enumerated() {
            let payload = seed.payload(sortIndex: index)
            guard let id = payload.id else { continue }
            kept.insert(id)
            do {
                if let card = existing[id] {
                    let changed = try factory.updateCard(card, from: payload)
                    if changed { report.updated += 1 }
                } else {
                    let card = try factory.createCard(from: payload)
                    context.insert(card)
                    card.deck = deck
                    report.inserted += 1
                }
            } catch {
                // Bundled content is ours; tests assert every card is valid.
                // At runtime, skip a bad card rather than block boot.
                Logger.seeding.error("Starter card \(seed.id, privacy: .public) invalid: \(String(describing: error))")
            }
        }

        for (id, card) in existing where !kept.contains(id) {
            context.delete(card)
            report.deleted += 1
        }
    }
}
