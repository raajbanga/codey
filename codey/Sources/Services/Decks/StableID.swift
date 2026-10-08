import CryptoKit
import Foundation

/// Deterministic UUIDs for bundled content. Starter decks and cards have
/// string keys in the JSON ("starter-ds", "sc-ds-001"); hashing them gives
/// the same UUID on every launch and every device, so upserts match rows
/// and user progress stays attached across content updates.
enum StableID {
    static func uuid(_ key: String, namespace: String = "codey.starter") -> UUID {
        let digest = SHA256.hash(data: Data("\(namespace):\(key)".utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x80 // version 8: custom, name-based
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
