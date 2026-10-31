import Foundation

/// Launch arguments for automation. Never set in normal launches.
enum AppLaunchOptions {
    /// `-UITestInMemoryStore`: UI tests start from a fresh, throwaway store
    /// so they never touch (or depend on) real local data.
    static var usesInMemoryStore: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestInMemoryStore")
    }

    /// UI tests skip onboarding (they always use the in-memory store), or
    /// pass `-SkipOnboarding` explicitly. `-UITestOnboarding` keeps it for
    /// the accessibility audit.
    static var skipsOnboarding: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-UITestOnboarding") { return false }
        return usesInMemoryStore || arguments.contains("-SkipOnboarding")
    }
}
