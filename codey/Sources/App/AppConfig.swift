import Foundation

/// Backend keys injected from Config/*.xcconfig through Info.plist.
/// Every value may be empty; the app then runs local-only (R11, NFR-08).
struct AppConfig: Equatable {
    let supabaseURL: URL?
    let supabaseAnonKey: String
    let googleIOSClientID: String
    let googleReversedClientID: String
    let googleServerClientID: String

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
    }

    /// True only when every key needed for Google sign-in + Supabase sync is set.
    var isBackendConfigured: Bool {
        supabaseURL?.scheme == "https"
            && !supabaseAnonKey.isEmpty
            && !googleIOSClientID.isEmpty
            && !googleReversedClientID.isEmpty
            && !googleServerClientID.isEmpty
    }
}
