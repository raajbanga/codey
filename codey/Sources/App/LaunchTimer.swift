import Darwin
import Foundation
import os

/// NFR-01 cold-launch metric (S3-F). Home logs, once per process, how long
/// it took from process start (the kernel's p_starttime) to Home's first
/// onAppear. scripts/perf-launch.sh reads the "home-ready" lines from the
/// Simulator log. The value is a duration, not user data, so it's public.
enum LaunchTimer {
    @MainActor private static var reported = false

    @MainActor
    static func markHomeReady() {
        guard !reported, let start = processStartDate() else { return }
        reported = true
        let ms = Date().timeIntervalSince(start) * 1000
        Logger.performance.notice("home-ready ms=\(ms, format: .fixed(precision: 1), privacy: .public)")
    }

    /// When this process started, from sysctl(KERN_PROC_PID).
    private static func processStartDate() -> Date? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else { return nil }
        let start = info.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1_000_000)
    }
}
