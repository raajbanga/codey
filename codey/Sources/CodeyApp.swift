import SwiftUI

/// App entry point. Applies the saved appearance (light/dark/system) and the
/// rounded navigation-title style, then hands off to LoadingView.
@main
struct CodeyApp: App {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    init() {
        AppAppearance.migrateLegacyPreference()
        CodeyNavigationTitles.apply()
    }

    var body: some Scene {
        WindowGroup {
            LoadingView()
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
