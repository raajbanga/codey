import SwiftUI

@main
struct CodeyApp: App {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    init() {
        AppAppearance.migrateLegacyPreference()
    }

    var body: some Scene {
        WindowGroup {
            LoadingView()
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
