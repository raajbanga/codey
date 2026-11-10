import CryptoKit
import Foundation

/// One-time value that ties a Google ID token to this sign-in attempt
/// (replay protection). Google embeds `hashed` in the token; Supabase is sent
/// `raw`, hashes it, and must get the same value.
struct SignInNonce: Sendable {
    let raw: String

    init(raw: String = SignInNonce.random()) {
        self.raw = raw
    }

    /// Lowercase hex SHA-256 of `raw`, the form Supabase compares against.
    var hashed: String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// 32 random bytes as URL-safe characters.
    static func random() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
