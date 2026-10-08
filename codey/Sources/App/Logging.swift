import Foundation
import os

/// One subsystem for every log line. Interpolated values default to private;
/// never mark tokens, emails, or user/deck IDs as `.public` (R10).
extension Logger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "edu.wku.cs360.codey"

    static let persistence = Logger(subsystem: subsystem, category: "Persistence")
    static let seeding = Logger(subsystem: subsystem, category: "Seeding")
    static let quiz = Logger(subsystem: subsystem, category: "Quiz")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
    static let study = Logger(subsystem: subsystem, category: "Study")
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
}
