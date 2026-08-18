//
//  KeychainStore.swift
//  TicketLedger
//
//  Tokens live in the keychain, never in UserDefaults: a plist is readable from
//  a device backup, a keychain item marked ThisDeviceOnly is not.
//

import Foundation
import Security

enum KeychainStore {
    private static let service = "com.TicketLedger.auth"

    @discardableResult
    static func save(_ data: Data, for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        // Written fresh every time, so a stale value can never survive a change.
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        // Available after the first unlock so a background sync can run, and
        // never copied to another device or into an iCloud backup.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func load(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: Convenience

    static func string(_ key: String) -> String? {
        load(key).flatMap { String(data: $0, encoding: .utf8) }
    }

    @discardableResult
    static func save(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data, for: key)
    }
}
