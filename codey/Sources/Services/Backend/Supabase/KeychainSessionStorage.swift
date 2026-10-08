import Foundation
import Security
import Supabase

/// Where the Supabase session lives (FR-02): the Keychain, never
/// UserDefaults. Unlike supabase-swift's default storage (AfterFirstUnlock),
/// items are ThisDeviceOnly, so they never leave the device in a backup.
/// Sign-out removes them (FR-03).
struct KeychainSessionStorage: AuthLocalStorage {
    static let defaultService = "edu.wku.cs360.codey.auth"

    let service: String
    /// A kSecAttrAccessible value (stored as String: CFString isn't Sendable).
    let accessibility: String

    init(service: String = Self.defaultService, accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly) {
        self.service = service
        self.accessibility = accessibility as String
    }

    func store(key: String, value: Data) throws {
        var query = baseQuery(key)
        let status = SecItemUpdate(query as CFDictionary, [
            kSecValueData: value,
            kSecAttrAccessible: accessibility,
        ] as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData] = value
            query[kSecAttrAccessible] = accessibility
            try check(SecItemAdd(query as CFDictionary, nil))
        } else {
            try check(status)
        }
    }

    func retrieve(key: String) throws -> Data? {
        var query = baseQuery(key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        try check(status)
        return result as? Data
    }

    func remove(key: String) throws {
        let status = SecItemDelete(baseQuery(key) as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }

    /// The stored item's kSecAttrAccessible value, for the FR-02 test.
    func accessibilityOfItem(key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnAttributes] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [CFString: Any] else { return nil }
        return attributes[kSecAttrAccessible] as? String
    }

    private func baseQuery(_ key: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }
}

struct KeychainError: Error, Equatable {
    let status: OSStatus
}
