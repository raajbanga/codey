import Foundation
import Testing
@testable import codey

/// BUG-02 regression: Supabase hashes the raw nonce with SHA-256 (lowercase
/// hex) and compares it with the nonce Google put in the ID token.
struct SignInNonceTests {

    @Test func hashIsLowercaseHexSHA256() {
        // SHA-256("abc"), the standard test vector.
        let nonce = SignInNonce(raw: "abc")
        #expect(nonce.hashed == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func randomNoncesAreUniqueAndURLSafe() {
        let a = SignInNonce(), b = SignInNonce()
        #expect(a.raw != b.raw)
        #expect(a.raw.count >= 43)
        #expect(a.raw.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }

    @Test func googleGetsHashSupabaseGetsRaw() {
        let nonce = SignInNonce()
        #expect(nonce.hashed != nonce.raw)
        #expect(nonce.hashed.count == 64)
    }
}
