//
//  SMTPService.swift
//  Enso
//

import Foundation
import SwiftMail
import SwiftData

/// Service for SMTP email sending operations using SwiftMail
actor SMTPService {

    // MARK: - Types

    enum SMTPError: LocalizedError {
        case notConnected
        case authenticationFailed
        case sendFailed(String)
        case connectionFailed(Error)
        case invalidRecipients

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Not connected to SMTP server"
            case .authenticationFailed:
                return "Authentication failed. Check your credentials."
            case .sendFailed(let reason):
                return "Failed to send email: \(reason)"
            case .connectionFailed(let error):
                return "Connection failed: \(error.localizedDescription)"
            case .invalidRecipients:
                return "No valid recipients specified"
            }
        }
    }

    /// Sendable data extracted from an Email for reply operations
    struct ReplyEmailData: Sendable {
        let fromAddress: String
        let toAddresses: [String]
        let ccAddresses: [String]
        let subject: String
        let messageId: String?
        let references: [String]

        @MainActor
        init(from email: Email) {
            self.fromAddress = email.fromAddress
            self.toAddresses = email.toAddresses
            self.ccAddresses = email.ccAddresses
            self.subject = email.subject
            self.messageId = email.messageId
            self.references = email.references
        }
    }

    /// Sendable data extracted from an Email for forward operations
    struct ForwardEmailData: Sendable {
        let fromAddress: String
        let toAddresses: [String]
        let subject: String
        let date: Date
        let textBody: String?

        @MainActor
        init(from email: Email) {
            self.fromAddress = email.fromAddress
            self.toAddresses = email.toAddresses
            self.subject = email.subject
            self.date = email.date
            self.textBody = email.textBody
        }
    }

    /// Sendable data extracted from an Account
    struct AccountData: Sendable {
        let emailAddress: String
        let displayName: String?
        let name: String
        let smtpHost: String
        let smtpPort: Int

        @MainActor
        init(from account: Account) {
            self.emailAddress = account.emailAddress
            self.displayName = account.displayName
            self.name = account.name
            self.smtpHost = account.smtpHost
            self.smtpPort = account.smtpPort
        }
    }

    // MARK: - Properties

    private var server: SwiftMail.SMTPServer?
    private let accountData: AccountData
    private let keychainService: KeychainService
    private let keychainIdentifier: String

    private var isConnected: Bool {
        server != nil
    }

    // MARK: - Initialization

    init(accountData: AccountData, keychainIdentifier: String, keychainService: KeychainService = .shared) {
        self.accountData = accountData
        self.keychainIdentifier = keychainIdentifier
        self.keychainService = keychainService
    }

    /// Convenience initializer that extracts data from Account on MainActor
    @MainActor
    init(account: Account, keychainService: KeychainService = .shared) {
        self.accountData = AccountData(from: account)
        self.keychainIdentifier = account.keychainIdentifier
        self.keychainService = keychainService
    }

    // MARK: - Connection

    /// Connect and authenticate with the SMTP server
    func connect() async throws {
        do {
            let server = SwiftMail.SMTPServer(host: accountData.smtpHost, port: accountData.smtpPort)
            try await server.connect()

            // Get password from keychain
            let password = try await keychainService.getPassword(for: keychainIdentifier, account: accountData.emailAddress)
            try await server.login(username: accountData.emailAddress, password: password)

            self.server = server
        } catch is KeychainService.KeychainError {
            throw SMTPError.authenticationFailed
        } catch {
            throw SMTPError.connectionFailed(error)
        }
    }

    /// Disconnect from the SMTP server
    func disconnect() async {
        if let server = server {
            try? await server.disconnect()
        }
        server = nil
    }

    /// Ensure we're connected before operations
    private func ensureConnected() async throws -> SwiftMail.SMTPServer {
        guard let server = server else {
            throw SMTPError.notConnected
        }
        return server
    }

    // MARK: - Email Sending

    /// Send an email
    func sendEmail(_ email: OutgoingEmail) async throws {
        let server = try await ensureConnected()

        // Validate recipients
        guard !email.toAddresses.isEmpty || !email.ccAddresses.isEmpty || !email.bccAddresses.isEmpty else {
            throw SMTPError.invalidRecipients
        }

        do {
            // Convert to SwiftMail Email format
            let smtpEmail = try createSMTPEmail(from: email)
            try await server.sendEmail(smtpEmail)
        } catch {
            throw SMTPError.sendFailed(error.localizedDescription)
        }
    }

    /// Send a reply to an existing email
    /// - Parameters:
    ///   - emailData: Sendable data extracted from the original email (use `ReplyEmailData(from:)` on MainActor)
    ///   - body: The reply body text
    ///   - htmlBody: Optional HTML body
    ///   - replyAll: Whether to reply to all recipients
    func sendReply(to emailData: ReplyEmailData, body: String, htmlBody: String? = nil, replyAll: Bool = false) async throws {
        let server = try await ensureConnected()

        let toAddresses = [emailData.fromAddress]
        var ccAddresses: [String] = []

        if replyAll {
            // Add original To recipients (except ourselves)
            ccAddresses = emailData.toAddresses.filter { $0 != accountData.emailAddress }
            // Add original CC recipients (except ourselves)
            ccAddresses += emailData.ccAddresses.filter { $0 != accountData.emailAddress }
        }

        let subject = emailData.subject.hasPrefix("Re:") ? emailData.subject : "Re: \(emailData.subject)"

        let outgoingEmail = OutgoingEmail(
            toAddresses: toAddresses,
            ccAddresses: ccAddresses,
            bccAddresses: [],
            subject: subject,
            textBody: body,
            htmlBody: htmlBody,
            inReplyTo: emailData.messageId,
            references: emailData.references
        )

        do {
            let smtpEmail = try createSMTPEmail(from: outgoingEmail)
            try await server.sendEmail(smtpEmail)
        } catch {
            throw SMTPError.sendFailed(error.localizedDescription)
        }
    }

    /// Forward an existing email
    /// - Parameters:
    ///   - emailData: Sendable data extracted from the original email (use `ForwardEmailData(from:)` on MainActor)
    ///   - recipients: The recipients to forward the email to
    ///   - body: Optional body text to prepend to the forwarded message
    func forwardEmail(_ emailData: ForwardEmailData, to recipients: [String], body: String? = nil) async throws {
        let server = try await ensureConnected()

        guard !recipients.isEmpty else {
            throw SMTPError.invalidRecipients
        }

        let subject = emailData.subject.hasPrefix("Fwd:") ? emailData.subject : "Fwd: \(emailData.subject)"

        var forwardedBody = body ?? ""
        forwardedBody += "\n\n---------- Forwarded message ----------\n"
        forwardedBody += "From: \(emailData.fromAddress)\n"
        forwardedBody += "Date: \(emailData.date.formatted())\n"
        forwardedBody += "Subject: \(emailData.subject)\n"
        forwardedBody += "To: \(emailData.toAddresses.joined(separator: ", "))\n\n"
        forwardedBody += emailData.textBody ?? ""

        let outgoingEmail = OutgoingEmail(
            toAddresses: recipients,
            ccAddresses: [],
            bccAddresses: [],
            subject: subject,
            textBody: forwardedBody,
            htmlBody: nil
        )

        do {
            let smtpEmail = try createSMTPEmail(from: outgoingEmail)
            try await server.sendEmail(smtpEmail)
        } catch {
            throw SMTPError.sendFailed(error.localizedDescription)
        }
    }

    // MARK: - Helper Methods

    /// Convert OutgoingEmail to SwiftMail Email format
    private func createSMTPEmail(from outgoing: OutgoingEmail) throws -> SwiftMail.Email {
        // Create sender address
        let senderName = accountData.displayName ?? accountData.name
        let sender = SwiftMail.EmailAddress(name: senderName, address: accountData.emailAddress)

        // Create recipients
        let toRecipients = outgoing.toAddresses.map { SwiftMail.EmailAddress(address: $0) }
        let ccRecipients = outgoing.ccAddresses.map { SwiftMail.EmailAddress(address: $0) }
        let bccRecipients = outgoing.bccAddresses.map { SwiftMail.EmailAddress(address: $0) }

        // Convert attachments
        var attachments: [SwiftMail.Attachment]? = nil
        if let outgoingAttachments = outgoing.attachments, !outgoingAttachments.isEmpty {
            attachments = outgoingAttachments.map { attachment in
                SwiftMail.Attachment(
                    filename: attachment.filename,
                    mimeType: attachment.mimeType,
                    data: attachment.data,
                    contentID: attachment.contentId,
                    isInline: attachment.isInline
                )
            }
        }

        return SwiftMail.Email(
            sender: sender,
            recipients: toRecipients,
            ccRecipients: ccRecipients,
            bccRecipients: bccRecipients,
            subject: outgoing.subject,
            textBody: outgoing.textBody,
            htmlBody: outgoing.htmlBody,
            attachments: attachments
        )
    }
}

// MARK: - Outgoing Email Model

/// Model for composing an outgoing email
struct OutgoingEmail: Sendable {
    let toAddresses: [String]
    let ccAddresses: [String]
    let bccAddresses: [String]
    let subject: String
    let textBody: String
    let htmlBody: String?
    let attachments: [OutgoingAttachment]?
    let inReplyTo: String?
    let references: [String]?

    nonisolated init(
        toAddresses: [String],
        ccAddresses: [String] = [],
        bccAddresses: [String] = [],
        subject: String,
        textBody: String,
        htmlBody: String? = nil,
        attachments: [OutgoingAttachment]? = nil,
        inReplyTo: String? = nil,
        references: [String]? = nil
    ) {
        self.toAddresses = toAddresses
        self.ccAddresses = ccAddresses
        self.bccAddresses = bccAddresses
        self.subject = subject
        self.textBody = textBody
        self.htmlBody = htmlBody
        self.attachments = attachments
        self.inReplyTo = inReplyTo
        self.references = references
    }
}

/// Model for outgoing attachments
struct OutgoingAttachment: Sendable {
    let filename: String
    let mimeType: String
    let data: Data
    let contentId: String?
    let isInline: Bool

    init(filename: String, mimeType: String, data: Data, contentId: String? = nil, isInline: Bool = false) {
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
        self.contentId = contentId
        self.isInline = isInline
    }

    /// Create from a file URL
    init(fileURL: URL, mimeType: String? = nil) throws {
        self.filename = fileURL.lastPathComponent
        self.data = try Data(contentsOf: fileURL)
        self.contentId = nil
        self.isInline = false

        // Determine MIME type if not provided
        if let providedMimeType = mimeType {
            self.mimeType = providedMimeType
        } else {
            let pathExtension = fileURL.pathExtension.lowercased()
            switch pathExtension {
            case "jpg", "jpeg": self.mimeType = "image/jpeg"
            case "png": self.mimeType = "image/png"
            case "gif": self.mimeType = "image/gif"
            case "pdf": self.mimeType = "application/pdf"
            case "txt": self.mimeType = "text/plain"
            case "html", "htm": self.mimeType = "text/html"
            case "doc", "docx": self.mimeType = "application/msword"
            case "xls", "xlsx": self.mimeType = "application/vnd.ms-excel"
            case "zip": self.mimeType = "application/zip"
            default: self.mimeType = "application/octet-stream"
            }
        }
    }
}
