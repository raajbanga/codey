import Darwin
import Foundation
import SwiftData
import Testing
@testable import codey

/// S3-F performance loop (Activity 9_2): run a scenario 10 times, discard
/// the first (cold caches), report mean / p95 / stddev. Each result prints
/// one `PERF` line that scripts/perf-report.sh turns into the CSV.
///
/// Opt-in: the suites run only with CODEY_PERF=1 in the test environment
/// (xcodebuild: TEST_RUNNER_CODEY_PERF=1), so the normal unit-test run stays
/// fast and timing noise never fails it.
enum Perf {
    static let isEnabled = ProcessInfo.processInfo.environment["CODEY_PERF"] == "1"
    static let iterations = 10

    struct Result {
        let name: String
        /// Milliseconds, first run discarded.
        let samples: [Double]
        /// Peak physical footprint seen across the kept runs, in MB.
        let peakMB: Double
        /// Most the footprint grew across one run (after body minus before
        /// it), in MB: what the scenario itself holds. The Simulator's
        /// absolute footprint also counts ~200 MB of iOS framework pages
        /// that a device keeps in the shared cache.
        var growthMB: Double = 0

        var mean: Double { samples.reduce(0, +) / Double(samples.count) }
        /// Nearest-rank p95 (with 9 samples this is the max).
        var p95: Double {
            let sorted = samples.sorted()
            let rank = Int((0.95 * Double(sorted.count)).rounded(.up))
            return sorted[max(0, rank - 1)]
        }
        var stddev: Double {
            let m = mean
            return (samples.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(samples.count)).squareRoot()
        }

        /// One parseable line per scenario.
        func report(thresholdMS: Double?) {
            let limit = thresholdMS.map { String(format: "%.0f", $0) } ?? "-"
            print(String(
                format: "PERF name=%@ runs=%d mean_ms=%.2f p95_ms=%.2f stddev_ms=%.2f peak_mb=%.1f growth_mb=%.1f threshold_ms=%@",
                name, samples.count, mean, p95, stddev, peakMB, growthMB, limit
            ))
        }
    }

    /// Times `body` `iterations` times. `setUp` runs before each iteration
    /// and is not timed.
    @MainActor
    static func measure<State>(
        _ name: String,
        thresholdMS: Double? = nil,
        setUp: () throws -> State,
        _ body: (State) throws -> Void
    ) rethrows -> Result {
        var samples: [Double] = []
        var peak = 0.0
        var growth = 0.0
        for _ in 0..<iterations {
            let state = try setUp()
            let before = footprintMB()
            let start = ContinuousClock.now
            try body(state)
            samples.append(milliseconds(ContinuousClock.now - start))
            let after = footprintMB()
            peak = max(peak, after)
            growth = max(growth, after - before)
        }
        var result = Result(name: name, samples: Array(samples.dropFirst()), peakMB: peak)
        result.growthMB = growth
        result.report(thresholdMS: thresholdMS)
        return result
    }

    @MainActor
    static func measureAsync<State>(
        _ name: String,
        thresholdMS: Double? = nil,
        setUp: () throws -> State,
        _ body: (State) async throws -> Void
    ) async rethrows -> Result {
        var samples: [Double] = []
        var peak = 0.0
        var growth = 0.0
        for _ in 0..<iterations {
            let state = try setUp()
            let before = footprintMB()
            let start = ContinuousClock.now
            try await body(state)
            samples.append(milliseconds(ContinuousClock.now - start))
            let after = footprintMB()
            peak = max(peak, after)
            growth = max(growth, after - before)
        }
        var result = Result(name: name, samples: Array(samples.dropFirst()), peakMB: peak)
        result.growthMB = growth
        result.report(thresholdMS: thresholdMS)
        return result
    }

    /// The process's physical footprint (what Xcode's memory gauge shows), MB.
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let (seconds, attoseconds) = duration.components
        return Double(seconds) * 1000 + Double(attoseconds) / 1e15
    }
}

/// Activity 9_2 test data, built through the real factory and validator.
@MainActor
enum PerfFixture {
    /// A user deck draft with `cards` cards; every third card carries a code
    /// snippet, tiers rotate Easy/Medium/Hard.
    static func draft(title: String = "Perf deck", cards: Int) -> DeckDraft {
        var draft = DeckDraft.new(topicId: "topic-data-structures")
        draft.title = title
        let tiers: [Difficulty] = [.easy, .medium, .hard]
        draft.cards = (0..<cards).map { n in
            CardDraft(
                prompt: "**Card \(n + 1).** What does this print, and why?",
                answer: "It prints `\(n)` because the loop runs once per element.",
                snippet: n % 3 == 0 ? SnippetDraft(language: .swift, source: snippet(lines: 12)) : nil,
                difficulty: tiers[n % tiers.count]
            )
        }
        return draft
    }

    /// A Swift snippet of exactly `lines` lines (the validator's max is 80).
    static func snippet(lines: Int) -> String {
        (0..<lines).map { n in
            switch n % 4 {
            case 0: "let value\(n) = [1, 2, 3].map { $0 * \(n) } // square-ish"
            case 1: "func step\(n)(_ x: Int) -> Int { x + \(n) }"
            case 2: "print(\"line \(n):\", step\(n - 1)(value\(n - 2).count))"
            default: "struct Box\(n) { var items: [String] = [] }"
            }
        }.joined(separator: "\n")
    }

    /// A seeded store: bundled topics/questions, starter decks, plus
    /// `userDecks` saved decks of `cardsPerDeck` cards each.
    static func seededContext(userDecks: Int = 0, cardsPerDeck: Int = 50) throws -> (ModelContext, BackendFacade) {
        let context = try TestSupport.inMemoryContext()
        try DataSeeder.seed(context: context, bank: QuestionBankLoader.loadBank())
        _ = try StarterDeckLoader.seed(context: context)
        let facade = BackendFacade.localOnly(context: context)
        for n in 0..<userDecks {
            _ = try facade.saveDeck(draft(title: "User deck \(n + 1)", cards: cardsPerDeck))
        }
        return (context, facade)
    }
}

extension Tag {
    @Tag static var performance: Self
}
