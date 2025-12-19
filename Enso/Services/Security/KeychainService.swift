//
//  KeychainService.swift
//  Enso
//

import Foundation
import Security

actor KeychainService {
    static let shared = KeychainService()

    enum KeychainError: LocalizedError {
        case duplicateItem
        case itemNotFound
        case unexpectedStatus(OSStatus)
        case invalidData

        var errorDescription: String? {
            switch self {
            case .duplicateItem:
                return "Item already exists in Keychain"
            case .itemNotFound:
                return "Item not found in Keychain"
            case .unexpectedStatus(let status):
                return "Unexpected Keychain error: \(status)"
            case .invalidData:
                return "Invalid data retrieved from Keychain"
            }
        }
    }

    private init() {}

    // MARK: - Password Storage

    func savePassword(_ password: String, for identifier: String, account: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrAccount as String: account,
            kSecAttrServer as String: identifier,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Update existing item
            try updatePassword(password, for: identifier, account: account)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func updatePassword(_ password: String, for identifier: String, account: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrAccount as String: account,
            kSecAttrServer as String: identifier
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: passwordData
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func getPassword(for identifier: String, account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrAccount as String: account,
            kSecAttrServer as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return password
    }

    func deletePassword(for identifier: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrAccount as String: account,
            kSecAttrServer as String: identifier
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Account Helpers

    func saveCredentials(for account: Account, password: String) throws {
        try savePassword(password, for: account.keychainIdentifier, account: account.emailAddress)
    }

    func getCredentials(for account: Account) throws -> String {
        try getPassword(for: account.keychainIdentifier, account: account.emailAddress)
    }

    func deleteCredentials(for account: Account) throws {
        try deletePassword(for: account.keychainIdentifier, account: account.emailAddress)
    }
}
