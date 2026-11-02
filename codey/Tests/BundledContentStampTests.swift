import Foundation
import SwiftData
import Testing
@testable import codey

/// Boot skips reseeding only when the bundle is unchanged AND the store has it.
@MainActor
struct BundledContentStampTests {
    private func defaults() -> UserDefaults {
        let name = "BundledContentStampTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func stampIsStableForTheBundle() throws {
        let stamp = try #require(BundledContentStamp.current())
        #expect(stamp.count == 64)
        #expect(BundledContentStamp.current() == stamp)
    }

    @Test func seededStoreWithMatchingStampSkips() throws {
        let context = try TestSupport.inMemoryContext()
        let defaults = defaults()
        let stamp = try #require(BundledContentStamp.current())
        try DataSeeder.seed(context: context, bank: QuestionBankLoader.loadBank())
        try StarterDeckLoader.seed(context: context)

        #expect(!BundledContentStamp.isSeeded(stamp, context: context, defaults: defaults), "no stamp recorded yet")
        BundledContentStamp.record(stamp, defaults: defaults)
        #expect(BundledContentStamp.isSeeded(stamp, context: context, defaults: defaults))
        #expect(!BundledContentStamp.isSeeded("changed-bundle", context: context, defaults: defaults))
    }

    @Test func emptyStoreSeedsEvenWithAMatchingStamp() throws {
        // A reset or in-memory store: the stamp alone must not skip.
        let context = try TestSupport.inMemoryContext()
        let defaults = defaults()
        let stamp = try #require(BundledContentStamp.current())
        BundledContentStamp.record(stamp, defaults: defaults)
        #expect(!BundledContentStamp.isSeeded(stamp, context: context, defaults: defaults))
    }
}
