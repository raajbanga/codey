import Foundation
import Observation

/// A fetched list with the FR-42 offline fallback: the cached copy shows
/// until the fetch lands, and stays (with `error` set) if it fails.
@MainActor
@Observable
final class CachedList<Item> {
    var items: [Item] = []
    private(set) var fetchedAt: Date?
    private(set) var isLoading = false
    private(set) var error: String?

    func load(cached: ([Item], Date)?, failure: String, fetch: () async throws -> [Item]) async {
        if items.isEmpty, let (cachedItems, date) = cached {
            items = cachedItems
            fetchedAt = date
        }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await fetch()
            fetchedAt = .now
            error = nil
        } catch {
            self.error = failure
        }
    }
}
