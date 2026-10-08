import Foundation
import SwiftData

extension Sequence {
    /// Elements by key; the first element wins on duplicate keys.
    func keyed<Key: Hashable>(by key: (Element) -> Key) -> [Key: Element] {
        Dictionary(map { (key($0), $0) }, uniquingKeysWith: { first, _ in first })
    }
}

extension Double {
    /// 0.42 → "42%".
    var percentText: String { formatted(.percent.precision(.fractionLength(0))) }
}

extension Int {
    /// "1 card", "3 cards".
    func counted(_ noun: String) -> String {
        "\(self) \(noun)\(self == 1 ? "" : "s")"
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
