import Foundation
import Security
import Testing
@testable import codey

/// FR-02/FR-03: the Supabase session is a ThisDeviceOnly Keychain item, never
/// in UserDefaults, and removing it (sign-out) deletes it.
@Suite(.serialized)
struct KeychainSessionStorageTests {
    private let storage = KeychainSessionStorage(service: "edu.wku.cs360.codey.tests.\(UUID().uuidString)")
    private let key = "sb-test-auth-token"

    @Test func storesInTheKeychainThisDeviceOnly() throws {
        defer { try? storage.remove(key: key) }
        let session = Data(#"{"access_token":"secret"}"#.utf8)
        try storage.store(key: key, value: session)

        #expect(try storage.retrieve(key: key) == session)
        #expect(storage.accessibilityOfItem(key: key) == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        // Nothing session-like leaked into UserDefaults.
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        #expect(defaults[key] == nil)
        #expect(!defaults.values.contains { ($0 as? Data) == session })
    }

    @Test func overwriteReplacesTheValue() throws {
        defer { try? storage.remove(key: key) }
        try storage.store(key: key, value: Data("one".utf8))
        try storage.store(key: key, value: Data("two".utf8))
        #expect(try storage.retrieve(key: key) == Data("two".utf8))
    }

    @Test func removeDeletesTheItem() throws {
        try storage.store(key: key, value: Data("session".utf8))
        try storage.remove(key: key)
        #expect(try storage.retrieve(key: key) == nil)
        // Removing again is fine (sign-out twice).
        try storage.remove(key: key)
    }
}
