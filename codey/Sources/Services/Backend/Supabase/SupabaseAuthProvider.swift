import Foundation
import GoogleSignIn
import Supabase
import UIKit
import os

/// Google sign-in → Supabase session (FR-01–03). Native flow: GoogleSignIn
/// returns an ID token, and Supabase verifies it against the Web client ID
/// and checks the nonce (see `SignInNonce`).
@MainActor
final class SupabaseAuthProvider: AuthProviding {
    private let client: SupabaseClient
    private let googleConfiguration: GIDConfiguration

    init(client: SupabaseClient, config: AppConfig) {
        self.client = client
        googleConfiguration = GIDConfiguration(
            clientID: config.googleIOSClientID,
            serverClientID: config.googleServerClientID
        )
        GIDSignIn.sharedInstance.configuration = googleConfiguration
    }

    func signIn(presenting viewController: UIViewController) async throws -> AppUser? {
        // BUG-02: GoogleSignIn 10 always puts a nonce in the ID token, and
        // Supabase rejects a token with a nonce unless we pass one too. Google
        // gets the SHA-256 hash; Supabase gets the raw value and hashes it.
        let nonce = SignInNonce()
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController,
                hint: nil,
                additionalScopes: nil,
                nonce: nonce.hashed
            )
        } catch let error as NSError where error.domain == kGIDSignInErrorDomain
            && error.code == GIDSignInError.canceled.rawValue {
            return nil
        }
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthProviderError.missingIDToken
        }
        let session = try await client.auth.signInWithIdToken(credentials: OpenIDConnectCredentials(
            provider: .google,
            idToken: idToken,
            accessToken: result.user.accessToken.tokenString,
            nonce: nonce.raw
        ))
        Logger.auth.notice("Signed in with Google")
        return AppUser(session.user)
    }

    func signOut() async {
        do {
            // .local: end this device's session only; other devices stay signed in.
            try await client.auth.signOut(scope: .local)
        } catch {
            Logger.auth.error("Supabase sign-out failed: \(String(describing: error))")
        }
        GIDSignIn.sharedInstance.signOut()
    }

    func currentUser() -> AppUser? {
        client.auth.currentUser.map(AppUser.init)
    }

    func currentUserID() -> UUID? {
        client.auth.currentUser?.id
    }

    func authStateStream() -> AsyncStream<AppUser?> {
        let changes = client.auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                for await change in changes {
                    switch change.event {
                    case .initialSession, .signedIn, .signedOut, .tokenRefreshed, .userUpdated, .userDeleted:
                        continuation.yield(change.session.map { AppUser($0.user) })
                    default:
                        continue
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}

enum AuthProviderError: Error, LocalizedError {
    case missingIDToken

    var errorDescription: String? {
        "Google didn't return an ID token."
    }
}

private extension AppUser {
    init(_ user: User) {
        let name = user.userMetadata["full_name"]?.stringValue ?? user.userMetadata["name"]?.stringValue
        self.init(id: user.id, email: user.email, displayName: name)
    }
}
