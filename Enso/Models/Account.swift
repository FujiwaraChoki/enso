import Foundation
import SwiftData

enum SyncStatus: String, Codable {
    case connected
    case syncing
    case error
    case offline
    case idle
}

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var emailAddress: String
    var displayName: String?

    // IMAP Configuration
    var imapHost: String
    var imapPort: Int
    var imapUseTLS: Bool

    // SMTP Configuration
    var smtpHost: String
    var smtpPort: Int
    var smtpUseTLS: Bool

    // Status
    var isActive: Bool
    var lastSyncDate: Date?
    var syncStatus: SyncStatus

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Folder.account)
    var folders: [Folder] = []

    @Relationship(deleteRule: .cascade, inverse: \Email.account)
    var emails: [Email] = []

    // Computed - credentials stored in Keychain
    var keychainIdentifier: String {
        "enso.account.\(id.uuidString)"
    }

    init(
        name: String,
        emailAddress: String,
        displayName: String? = nil,
        imapHost: String,
        imapPort: Int = 993,
        imapUseTLS: Bool = true,
        smtpHost: String,
        smtpPort: Int = 587,
        smtpUseTLS: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.emailAddress = emailAddress
        self.displayName = displayName
        self.imapHost = imapHost
        self.imapPort = imapPort
        self.imapUseTLS = imapUseTLS
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.smtpUseTLS = smtpUseTLS
        self.isActive = true
        self.syncStatus = .idle
    }
}
