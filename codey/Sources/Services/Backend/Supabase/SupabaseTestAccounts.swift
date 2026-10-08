#if DEBUG
import Foundation
import Supabase

/// Opt-in integration tests only (9.7): signs a test account in with email +
/// password against SUPABASE_TEST_URL. Never used by the app. Lives here
/// because only this folder may import Supabase.
enum SupabaseTestAccounts {
    struct Session {
        let userID: UUID
        let remote: any RemoteDeckStore
        /// Hard-deletes every deck this account owns (cards cascade).
        let deleteAllDecks: @Sendable () async throws -> Void
    }

    /// A signed-out data client on a custom session (unit tests stub the
    /// network with a URLProtocol).
    static func dataClient(url: URL, key: String, configuration: URLSessionConfiguration) -> any RemoteDeckStore {
        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: .init(storage: KeychainSessionStorage(service: "edu.wku.cs360.codey.stub.\(UUID().uuidString)"),
                            autoRefreshToken: false, emitLocalSessionAsInitialSession: true),
                global: .init(session: URLSession(configuration: configuration))
            )
        )
        return SupabaseDataClient(client: client)
    }

    static func signIn(url: URL, key: String, email: String, password: String) async throws -> Session {
        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(auth: .init(
                storage: KeychainSessionStorage(service: "edu.wku.cs360.codey.integration.\(UUID().uuidString)"),
                autoRefreshToken: false,
                emitLocalSessionAsInitialSession: true
            ), global: .init(session: URLSession(configuration: SupabaseServices.tlsConfiguration)))
        )
        let session = try await client.auth.signIn(email: email, password: password)
        let userID = session.user.id
        return Session(
            userID: userID,
            remote: SupabaseDataClient(client: client),
            deleteAllDecks: {
                try await client.from("decks").delete().eq("owner_id", value: userID.uuidString).execute()
            }
        )
    }
}
#endif
