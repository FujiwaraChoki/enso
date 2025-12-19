//
//  KeychainServiceProtocol.swift
//  EnsoTests
//

import Foundation
@testable import Enso

/// Protocol for KeychainService to enable testing with mocks
protocol KeychainServiceProtocol: Actor {
    /// Save password for a given identifier and account
    func savePassword(_ password: String, for identifier: String, account: String) throws

    /// Retrieve password for a given identifier and account
    func getPassword(for identifier: String, account: String) throws -> String

    /// Delete password for a given identifier and account
    func deletePassword(for identifier: String, account: String) throws

    /// Save credentials for an Account model
    func saveCredentials(for account: Account, password: String) throws

    /// Get credentials for an Account model
    func getCredentials(for account: Account) throws -> String

    /// Delete credentials for an Account model
    func deleteCredentials(for account: Account) throws
}

// MARK: - KeychainService Conformance

extension KeychainService: KeychainServiceProtocol {}
