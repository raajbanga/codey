#if DEBUG
import Foundation
import Supabase

/// Unit tests only: a signed-out Supabase data client on a custom URL session,
/// so `SupabaseDataClientTests` can stub the network with a URLProtocol.
/// Never used by the app; DEBUG-only (NFR-26). Lives here because only this
/// folder may import Supabase.
enum SupabaseTestClient {
    static func dataClient(url: URL, key: String, configuration: URLSessionConfiguration, pageSize: Int = 1000) -> any RemoteDeckStore {
        SupabaseDataClient(client: makeClient(url: url, key: key, configuration: configuration), pageSize: pageSize)
    }

    /// A client with its own throwaway Keychain service and no auto-refresh.
    private static func makeClient(url: URL, key: String, configuration: URLSessionConfiguration) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(
                db: SupabaseDataClient.databaseOptions,
                auth: .init(
                    storage: KeychainSessionStorage(service: "edu.wku.cs360.codey.tests.\(UUID().uuidString)"),
                    autoRefreshToken: false,
                    emitLocalSessionAsInitialSession: true
                ),
                global: .init(session: URLSession(configuration: configuration))
            )
        )
    }
}
#endif
