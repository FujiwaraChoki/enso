//
//  MockKeychainService.swift
//  EnsoTests
//

import Foundation
@testable import Enso

/// Mock implementation of KeychainServiceProtocol for testing
actor MockKeychainService: KeychainServiceProtocol {

    // MARK: - Storage

    private var storage: [String: String] = [:]

    // MARK: - Tracking

    private(set) var savePasswordCallCount = 0
    private(set) var getPasswordCallCount = 0
    private(set) var deletePasswordCallCount = 0
    private(set) var lastSavedIdentifier: String?
    private(set) var lastSavedAccount: String?
    private(set) var lastRetrievedIdentifier: String?
    private(set) var lastRetrievedAccount: String?

    // MARK: - Error Injection

    var shouldThrowOnSave: KeychainService.KeychainError?
    var shouldThrowOnGet: KeychainService.KeychainError?
    var shouldThrowOnDelete: KeychainService.KeychainError?

    // MARK: - Protocol Implementation

    func savePassword(_ password: String, for identifier: String, account: String) throws {
        savePasswordCallCount += 1
        lastSavedIdentifier = identifier
        lastSavedAccount = account

        if let error = shouldThrowOnSave {
            throw error
        }

        let key = makeKey(identifier: identifier, account: account)
        storage[key] = password
    }

    func getPassword(for identifier: String, account: String) throws -> String {
        getPasswordCallCount += 1
        lastRetrievedIdentifier = identifier
        lastRetrievedAccount = account

        if let error = shouldThrowOnGet {
            throw error
        }

        let key = makeKey(identifier: identifier, account: account)
        guard let password = storage[key] else {
            throw KeychainService.KeychainError.itemNotFound
        }

        return password
    }

    func deletePassword(for identifier: String, account: String) throws {
        deletePasswordCallCount += 1

        if let error = shouldThrowOnDelete {
            throw error
        }

        let key = makeKey(identifier: identifier, account: account)
        storage.removeValue(forKey: key)
    }

    func saveCredentials(for account: Account, password: String) throws {
        try savePassword(password, for: account.keychainIdentifier, account: account.emailAddress)
    }

    func getCredentials(for account: Account) throws -> String {
        try getPassword(for: account.keychainIdentifier, account: account.emailAddress)
    }

    func deleteCredentials(for account: Account) throws {
        try deletePassword(for: account.keychainIdentifier, account: account.emailAddress)
    }

    // MARK: - Test Helpers

    /// Reset all state
    func reset() {
        storage.removeAll()
        savePasswordCallCount = 0
        getPasswordCallCount = 0
        deletePasswordCallCount = 0
        lastSavedIdentifier = nil
        lastSavedAccount = nil
        lastRetrievedIdentifier = nil
        lastRetrievedAccount = nil
        shouldThrowOnSave = nil
        shouldThrowOnGet = nil
        shouldThrowOnDelete = nil
    }

    /// Pre-populate storage with credentials
    func setStoredPassword(_ password: String, for identifier: String, account: String) {
        let key = makeKey(identifier: identifier, account: account)
        storage[key] = password
    }

    /// Check if a password exists
    func hasPassword(for identifier: String, account: String) -> Bool {
        let key = makeKey(identifier: identifier, account: account)
        return storage[key] != nil
    }

    /// Get the total number of stored passwords
    var storedPasswordCount: Int {
        storage.count
    }

    // MARK: - Private Helpers

    private func makeKey(identifier: String, account: String) -> String {
        "\(identifier):\(account)"
    }
}
