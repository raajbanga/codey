import SwiftUI
import UIKit

/// User appearance preference (NFR-11). Applied at the app root through the
/// window scene's trait override (see `apply(to:)`).
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

    /// The window trait for this preference; `.unspecified` follows the system.
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Sets the style on every window, so sheets, covers and
    /// alerts follow at once. Not `.preferredColorScheme`: going back to
    /// `nil` (System) after Light or Dark leaves the window on the last
    /// explicit scheme, and a change made from inside a sheet reached the
    /// views under it late, so switching looked stuck.
    @MainActor
    func apply(to application: UIApplication = .shared) {
        // The window's override, not the scene's `traitOverrides`: changing
        // the scene trait dismissed an open sheet. On a window `.unspecified`
        // means no override, so System follows the device again.
        for case let scene as UIWindowScene in application.connectedScenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
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
