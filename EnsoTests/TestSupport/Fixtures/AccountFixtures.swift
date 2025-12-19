//
//  AccountFixtures.swift
//  EnsoTests
//

import Foundation
@testable import Enso

/// Factory for creating Account test fixtures
enum AccountFixtures {

    // MARK: - Basic Factory

    /// Create a test account with customizable properties
    static func createAccount(
        name: String = "Test Account",
        emailAddress: String = "test@example.com",
        displayName: String? = nil,
        imapHost: String = "imap.example.com",
        imapPort: Int = 993,
        imapUseTLS: Bool = true,
        smtpHost: String = "smtp.example.com",
        smtpPort: Int = 587,
        smtpUseTLS: Bool = true,
        isActive: Bool = true,
        syncStatus: SyncStatus = .idle,
        lastSyncDate: Date? = nil
    ) -> Account {
        let account = Account(
            name: name,
            emailAddress: emailAddress,
            displayName: displayName,
            imapHost: imapHost,
            imapPort: imapPort,
            imapUseTLS: imapUseTLS,
            smtpHost: smtpHost,
            smtpPort: smtpPort,
            smtpUseTLS: smtpUseTLS
        )
        account.isActive = isActive
        account.syncStatus = syncStatus
        account.lastSyncDate = lastSyncDate
        return account
    }

    // MARK: - Preset Configurations

    /// Create a Gmail account configuration
    static func createGmailAccount(
        emailAddress: String = "user@gmail.com",
        displayName: String? = "Gmail User"
    ) -> Account {
        createAccount(
            name: "Gmail",
            emailAddress: emailAddress,
            displayName: displayName,
            imapHost: "imap.gmail.com",
            imapPort: 993,
            smtpHost: "smtp.gmail.com",
            smtpPort: 587
        )
    }

    /// Create an Outlook account configuration
    static func createOutlookAccount(
        emailAddress: String = "user@outlook.com",
        displayName: String? = "Outlook User"
    ) -> Account {
        createAccount(
            name: "Outlook",
            emailAddress: emailAddress,
            displayName: displayName,
            imapHost: "outlook.office365.com",
            imapPort: 993,
            smtpHost: "smtp.office365.com",
            smtpPort: 587
        )
    }

    /// Create an iCloud account configuration
    static func createiCloudAccount(
        emailAddress: String = "user@icloud.com",
        displayName: String? = "iCloud User"
    ) -> Account {
        createAccount(
            name: "iCloud",
            emailAddress: emailAddress,
            displayName: displayName,
            imapHost: "imap.mail.me.com",
            imapPort: 993,
            smtpHost: "smtp.mail.me.com",
            smtpPort: 587
        )
    }

    // MARK: - State Variations

    /// Create an inactive account
    static func createInactiveAccount() -> Account {
        createAccount(
            name: "Inactive Account",
            emailAddress: "inactive@example.com",
            isActive: false
        )
    }

    /// Create an account that is currently syncing
    static func createSyncingAccount() -> Account {
        createAccount(
            name: "Syncing Account",
            emailAddress: "syncing@example.com",
            syncStatus: .syncing
        )
    }

    /// Create an account with a sync error
    static func createErrorAccount() -> Account {
        createAccount(
            name: "Error Account",
            emailAddress: "error@example.com",
            syncStatus: .error
        )
    }

    /// Create an account that was recently synced
    static func createRecentlySyncedAccount() -> Account {
        createAccount(
            name: "Recently Synced",
            emailAddress: "recent@example.com",
            syncStatus: .idle,
            lastSyncDate: Date()
        )
    }

    /// Create an account that needs syncing (stale cache)
    static func createStaleCacheAccount() -> Account {
        createAccount(
            name: "Stale Cache",
            emailAddress: "stale@example.com",
            syncStatus: .idle,
            lastSyncDate: Date().addingTimeInterval(-600) // 10 minutes ago
        )
    }

    // MARK: - Batch Creation

    /// Create multiple test accounts
    static func createMultipleAccounts(count: Int = 3) -> [Account] {
        (1...count).map { index in
            createAccount(
                name: "Account \(index)",
                emailAddress: "user\(index)@example.com"
            )
        }
    }
}
