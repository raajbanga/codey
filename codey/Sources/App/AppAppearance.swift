import SwiftUI

/// User appearance preference (NFR-11). Applied once at the app root.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearance"
    static let legacyDarkModeKey = "preferredDarkMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// nil follows the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Carries over the old 2-state dark-mode toggle, then deletes its key.
    /// An old "on" becomes Dark; an old "off" becomes System (the toggle
    /// defaulted to off, so "off" never meant an explicit Light choice).
    static func migrateLegacyPreference(in defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: legacyDarkModeKey) != nil else { return }
        if defaults.string(forKey: storageKey) == nil, defaults.bool(forKey: legacyDarkModeKey) {
            defaults.set(AppAppearance.dark.rawValue, forKey: storageKey)
        }
        defaults.removeObject(forKey: legacyDarkModeKey)
    }
}
