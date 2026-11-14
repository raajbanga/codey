import Foundation

/// Backend keys injected from Config/*.xcconfig through Info.plist.
/// Every value may be empty; the app then runs local-only (R11, NFR-08).
struct AppConfig: Equatable {
    let supabaseURL: URL?
    let supabaseAnonKey: String
    let googleIOSClientID: String
    let googleReversedClientID: String
    let googleServerClientID: String
    /// Ask AI (S39). Empty = the Ask AI button is hidden.
    let openRouterAPIKey: String
    /// A free OpenRouter model ID; the free catalog rotates, so it is config.
    let openRouterModel: String

    /// Used when OPENROUTER_MODEL is empty: OpenRouter picks any free model.
    static let fallbackOpenRouterModel = "openrouter/free"

    static let current = AppConfig(infoDictionary: Bundle.main.infoDictionary ?? [:])

    init(infoDictionary: [String: Any]) {
        func value(_ key: String) -> String {
            let raw = (infoDictionary[key] as? String ?? "").trimmingCharacters(in: .whitespaces)
            // An unresolved "$(KEY)" means the build setting was never defined.
            return raw.hasPrefix("$(") ? "" : raw
        }

        let urlString = value("SUPABASE_URL")
        supabaseURL = urlString.isEmpty ? nil : URL(string: urlString)
        supabaseAnonKey = value("SUPABASE_ANON_KEY")
        googleIOSClientID = value("GOOGLE_IOS_CLIENT_ID")
        googleReversedClientID = value("GOOGLE_REVERSED_CLIENT_ID")
        googleServerClientID = value("GOOGLE_SERVER_CLIENT_ID")
        openRouterAPIKey = value("OPENROUTER_API_KEY")
        let model = value("OPENROUTER_MODEL")
        openRouterModel = model.isEmpty ? Self.fallbackOpenRouterModel : model
    }

    /// True when the Ask AI button can show (a key is set).
    var isAskAIConfigured: Bool { !openRouterAPIKey.isEmpty }

    /// True only when every key needed for Google sign-in + Supabase sync is set.
    var isBackendConfigured: Bool {
        supabaseURL?.scheme == "https"
            && !supabaseAnonKey.isEmpty
            && !googleIOSClientID.isEmpty
            && !googleReversedClientID.isEmpty
            && !googleServerClientID.isEmpty
    }
}
