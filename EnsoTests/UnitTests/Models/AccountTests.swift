//
//  AccountTests.swift
//  EnsoTests
//

import XCTest
import SwiftData
@testable import Enso

final class AccountTests: XCTestCase {

    // MARK: - keychainIdentifier Tests

    func test_keychainIdentifier_hasCorrectPrefix() {
        let account = AccountFixtures.createAccount()

        XCTAssertTrue(account.keychainIdentifier.hasPrefix("enso.account."))
    }

    func test_keychainIdentifier_containsUUID() {
        let account = AccountFixtures.createAccount()
        let identifier = account.keychainIdentifier

        // Remove prefix and check if remainder is valid UUID
        let uuidString = identifier.replacingOccurrences(of: "enso.account.", with: "")
        XCTAssertNotNil(UUID(uuidString: uuidString))
    }

    func test_keychainIdentifier_isUnique() {
        let account1 = AccountFixtures.createAccount()
        let account2 = AccountFixtures.createAccount()

        XCTAssertNotEqual(account1.keychainIdentifier, account2.keychainIdentifier)
    }

    func test_keychainIdentifier_isConsistent() {
        let account = AccountFixtures.createAccount()

        let identifier1 = account.keychainIdentifier
        let identifier2 = account.keychainIdentifier

        XCTAssertEqual(identifier1, identifier2)
    }

    // MARK: - Initialization Tests

    func test_init_setsDefaultValues() {
        let account = Account(
            name: "Test",
            emailAddress: "test@example.com",
            imapHost: "imap.example.com",
            smtpHost: "smtp.example.com"
        )

        XCTAssertEqual(account.imapPort, 993)
        XCTAssertEqual(account.smtpPort, 587)
        XCTAssertTrue(account.imapUseTLS)
        XCTAssertTrue(account.smtpUseTLS)
        XCTAssertTrue(account.isActive)
        XCTAssertEqual(account.syncStatus, .idle)
        XCTAssertNil(account.lastSyncDate)
        XCTAssertNil(account.displayName)
    }

    func test_init_acceptsCustomPorts() {
        let account = Account(
            name: "Test",
            emailAddress: "test@example.com",
            imapHost: "imap.example.com",
            imapPort: 143,
            smtpHost: "smtp.example.com",
            smtpPort: 25
        )

        XCTAssertEqual(account.imapPort, 143)
        XCTAssertEqual(account.smtpPort, 25)
    }

    func test_init_acceptsCustomTLSSettings() {
        let account = Account(
            name: "Test",
            emailAddress: "test@example.com",
            imapHost: "imap.example.com",
            imapUseTLS: false,
            smtpHost: "smtp.example.com",
            smtpUseTLS: false
        )

        XCTAssertFalse(account.imapUseTLS)
        XCTAssertFalse(account.smtpUseTLS)
    }

    // MARK: - SyncStatus Tests

    func test_syncStatus_canBeModified() {
        let account = AccountFixtures.createAccount()

        account.syncStatus = .syncing
        XCTAssertEqual(account.syncStatus, .syncing)

        account.syncStatus = .connected
        XCTAssertEqual(account.syncStatus, .connected)

        account.syncStatus = .error
        XCTAssertEqual(account.syncStatus, .error)

        account.syncStatus = .offline
        XCTAssertEqual(account.syncStatus, .offline)

        account.syncStatus = .idle
        XCTAssertEqual(account.syncStatus, .idle)
    }

    // MARK: - isActive Tests

    func test_isActive_canBeModified() {
        let account = AccountFixtures.createAccount()
        XCTAssertTrue(account.isActive)

        account.isActive = false
        XCTAssertFalse(account.isActive)
    }

    // MARK: - lastSyncDate Tests

    func test_lastSyncDate_canBeSet() {
        let account = AccountFixtures.createAccount()
        let date = Date()

        account.lastSyncDate = date

        XCTAssertEqual(account.lastSyncDate, date)
    }

    func test_lastSyncDate_canBeCleared() {
        let account = AccountFixtures.createRecentlySyncedAccount()
        XCTAssertNotNil(account.lastSyncDate)

        account.lastSyncDate = nil

        XCTAssertNil(account.lastSyncDate)
    }

    // MARK: - Relationship Tests

    func test_folders_startsEmpty() {
        let account = AccountFixtures.createAccount()

        XCTAssertTrue(account.folders.isEmpty)
    }

    func test_emails_startsEmpty() {
        let account = AccountFixtures.createAccount()

        XCTAssertTrue(account.emails.isEmpty)
    }

    // MARK: - Fixture Tests

    func test_gmailAccount_hasCorrectSettings() {
        let account = AccountFixtures.createGmailAccount()

        XCTAssertEqual(account.name, "Gmail")
        XCTAssertEqual(account.imapHost, "imap.gmail.com")
        XCTAssertEqual(account.smtpHost, "smtp.gmail.com")
        XCTAssertTrue(account.emailAddress.contains("@gmail.com"))
    }

    func test_outlookAccount_hasCorrectSettings() {
        let account = AccountFixtures.createOutlookAccount()

        XCTAssertEqual(account.name, "Outlook")
        XCTAssertEqual(account.imapHost, "outlook.office365.com")
        XCTAssertEqual(account.smtpHost, "smtp.office365.com")
    }

    func test_iCloudAccount_hasCorrectSettings() {
        let account = AccountFixtures.createiCloudAccount()

        XCTAssertEqual(account.name, "iCloud")
        XCTAssertEqual(account.imapHost, "imap.mail.me.com")
        XCTAssertEqual(account.smtpHost, "smtp.mail.me.com")
    }

    func test_inactiveAccount_isNotActive() {
        let account = AccountFixtures.createInactiveAccount()

        XCTAssertFalse(account.isActive)
    }

    func test_syncingAccount_hasSyncingStatus() {
        let account = AccountFixtures.createSyncingAccount()

        XCTAssertEqual(account.syncStatus, .syncing)
    }

    func test_errorAccount_hasErrorStatus() {
        let account = AccountFixtures.createErrorAccount()

        XCTAssertEqual(account.syncStatus, .error)
    }

    func test_recentlySyncedAccount_hasRecentDate() {
        let account = AccountFixtures.createRecentlySyncedAccount()

        XCTAssertNotNil(account.lastSyncDate)
        if let syncDate = account.lastSyncDate {
            XCTAssertTrue(Date().timeIntervalSince(syncDate) < 60) // Within last minute
        }
    }

    func test_staleCacheAccount_hasOldDate() {
        let account = AccountFixtures.createStaleCacheAccount()

        XCTAssertNotNil(account.lastSyncDate)
        if let syncDate = account.lastSyncDate {
            XCTAssertTrue(Date().timeIntervalSince(syncDate) >= 600) // At least 10 minutes ago
        }
    }

    func test_multipleAccounts_areCreated() {
        let accounts = AccountFixtures.createMultipleAccounts(count: 5)

        XCTAssertEqual(accounts.count, 5)

        // Each should have unique identifier
        let identifiers = Set(accounts.map { $0.keychainIdentifier })
        XCTAssertEqual(identifiers.count, 5)
    }
}
