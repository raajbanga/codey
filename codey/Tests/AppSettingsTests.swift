import Foundation
import SwiftUI
import Testing
@testable import codey

struct AppAppearanceTests {

    private func makeDefaults() -> UserDefaults {
        let name = "codey-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func colorSchemes() {
        #expect(AppAppearance.system.colorScheme == nil)
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
    }

    @Test func legacyDarkOnBecomesDark() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: AppAppearance.legacyDarkModeKey)

        AppAppearance.migrateLegacyPreference(in: defaults)

        #expect(defaults.string(forKey: AppAppearance.storageKey) == "dark")
        #expect(defaults.object(forKey: AppAppearance.legacyDarkModeKey) == nil)
    }

    @Test func legacyDarkOffFollowsSystem() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: AppAppearance.legacyDarkModeKey)

        AppAppearance.migrateLegacyPreference(in: defaults)

        #expect(defaults.string(forKey: AppAppearance.storageKey) == nil)
        #expect(defaults.object(forKey: AppAppearance.legacyDarkModeKey) == nil)
    }

    @Test func existingChoiceWins() {
        let defaults = makeDefaults()
        defaults.set("light", forKey: AppAppearance.storageKey)
        defaults.set(true, forKey: AppAppearance.legacyDarkModeKey)

        AppAppearance.migrateLegacyPreference(in: defaults)

        #expect(defaults.string(forKey: AppAppearance.storageKey) == "light")
    }
}

struct AppConfigTests {

    private let complete: [String: Any] = [
        "SUPABASE_URL": "https://abc.supabase.co",
        "SUPABASE_ANON_KEY": "anon",
        "GOOGLE_IOS_CLIENT_ID": "ios",
        "GOOGLE_REVERSED_CLIENT_ID": "reversed",
        "GOOGLE_SERVER_CLIENT_ID": "server",
    ]

    @Test func emptySecretsMeanLocalOnly() {
        let config = AppConfig(infoDictionary: [:])
        #expect(!config.isBackendConfigured)
        #expect(config.supabaseURL == nil)
    }

    @Test func unresolvedBuildSettingsAreEmpty() {
        let config = AppConfig(infoDictionary: ["SUPABASE_URL": "$(SUPABASE_URL)", "SUPABASE_ANON_KEY": "$(SUPABASE_ANON_KEY)"])
        #expect(config.supabaseURL == nil)
        #expect(config.supabaseAnonKey.isEmpty)
    }

    @Test func completeConfigIsConfigured() {
        let config = AppConfig(infoDictionary: complete)
        #expect(config.isBackendConfigured)
        #expect(config.supabaseURL?.host() == "abc.supabase.co")
    }

    @Test func nonHTTPSURLIsRejected() {
        var dict = complete
        dict["SUPABASE_URL"] = "http://abc.supabase.co"
        #expect(!AppConfig(infoDictionary: dict).isBackendConfigured)
    }
}

/// NFR-06: no App Transport Security exceptions; the backend is HTTPS only.
struct TransportSecurityTests {
    @Test func appHasNoATSExceptions() {
        // Unit tests are hosted in the app, so Bundle.main is codey.app.
        #expect(Bundle.main.bundleIdentifier == "edu.wku.cs360.codey")
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") == nil)
    }

    @Test func plainHTTPBackendIsNotConfigured() {
        let config = AppConfig(infoDictionary: [
            "SUPABASE_URL": "http://example.supabase.co", "SUPABASE_ANON_KEY": "k",
            "GOOGLE_IOS_CLIENT_ID": "i", "GOOGLE_REVERSED_CLIENT_ID": "r", "GOOGLE_SERVER_CLIENT_ID": "s",
        ])
        #expect(!config.isBackendConfigured)
    }
}

extension TransportSecurityTests {
    @Test func backendSessionRequiresTLS13() {
        #expect(SupabaseServices.tlsConfiguration.tlsMinimumSupportedProtocolVersion == .TLSv13)
    }
}
