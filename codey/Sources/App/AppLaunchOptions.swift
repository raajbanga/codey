import Foundation

/// Launch arguments for automation. Never set in normal launches.
enum AppLaunchOptions {
    /// `-UITestInMemoryStore`: UI tests start from a fresh, throwaway store
    /// so they never touch (or depend on) real local data.
    static var usesInMemoryStore: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestInMemoryStore")
    }

    /// UI tests skip onboarding (they always use the in-memory store), or
    /// pass `-SkipOnboarding` explicitly.
    static var skipsOnboarding: Bool {
        usesInMemoryStore || ProcessInfo.processInfo.arguments.contains("-SkipOnboarding")
    }
}
