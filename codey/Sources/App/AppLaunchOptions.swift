import Foundation

/// Launch arguments for automation. Never set in normal launches.
enum AppLaunchOptions {
    /// `-UITestInMemoryStore`: UI tests start from a fresh, throwaway store
    /// so they never touch (or depend on) real local data.
    static var usesInMemoryStore: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestInMemoryStore")
    }
}
