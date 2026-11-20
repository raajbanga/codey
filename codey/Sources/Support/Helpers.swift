import Foundation
import SwiftData

// Small shared helpers used across features. Kept generic: anything
// feature-specific belongs next to that feature.

extension Sequence {
    /// Elements by key; the first element wins on duplicate keys.
    func keyed<Key: Hashable>(by key: (Element) -> Key) -> [Key: Element] {
        Dictionary(map { (key($0), $0) }, uniquingKeysWith: { first, _ in first })
    }
}

extension Array {
    /// Consecutive slices of at most `size` (one request each).
    func chunked(into size: Int) -> [ArraySlice<Element>] {
        stride(from: 0, to: count, by: size).map { self[$0..<Swift.min($0 + size, count)] }
    }
}

extension Double {
    /// 0.42 → "42%".
    var percentText: String { formatted(.percent.precision(.fractionLength(0))) }
}

extension Int {
    /// "1 card", "3 cards"; `plural` for nouns that don't just add s.
    func counted(_ noun: String, plural: String? = nil) -> String {
        "\(self) \(self == 1 ? noun : plural ?? noun + "s")"
    }
}

extension ModelContext {
    /// The first matching row, or nil.
    func first<T: PersistentModel>(_ predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) throws -> T? {
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: sortBy)
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }
}
