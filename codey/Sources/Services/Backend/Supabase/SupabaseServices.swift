import Foundation
import Supabase

/// Builds the live auth + remote store. The only place a SupabaseClient is
/// created; nil when the build has no backend keys (local-only, R11).
enum SupabaseServices {
    @MainActor
    static func make(config: AppConfig = .current) -> (auth: any AuthProviding, remote: any RemoteDeckStore)? {
        guard config.isBackendConfigured, let url = config.supabaseURL else { return nil }
        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: config.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: KeychainSessionStorage(),
                    // Restore the stored session at launch even if it needs a
                    // refresh; the client refreshes it before the first request.
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        return (SupabaseAuthProvider(client: client, config: config), SupabaseDataClient(client: client))
    }
}
