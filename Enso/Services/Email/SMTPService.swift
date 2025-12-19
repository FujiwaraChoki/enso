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

    // MARK: - Properties

    private var server: SwiftMail.SMTPServer?
    private let account: Account
    private let keychainService: KeychainService

    private var isConnected: Bool {
        server != nil
    }

    // MARK: - Initialization

    init(account: Account, keychainService: KeychainService = .shared) {
        self.account = account
        self.keychainService = keychainService
    }

    // MARK: - Connection

    /// Connect and authenticate with the SMTP server
    func connect() async throws {
        do {
            let server = SwiftMail.SMTPServer(host: account.smtpHost, port: account.smtpPort)
            try await server.connect()

            // Get password from keychain
            let password = try await keychainService.getCredentials(for: account)
            try await server.login(username: account.emailAddress, password: password)

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
    func sendReply(to originalEmail: Email, body: String, htmlBody: String? = nil, replyAll: Bool = false) async throws {
        let server = try await ensureConnected()

        let (toAddresses, ccAddresses, subject, inReplyTo, references) = await MainActor.run {
            let toAddresses = [originalEmail.fromAddress]
            var ccAddresses: [String] = []

            if replyAll {
                // Add original To recipients (except ourselves)
                ccAddresses = originalEmail.toAddresses.filter { $0 != account.emailAddress }
                // Add original CC recipients (except ourselves)
                ccAddresses += originalEmail.ccAddresses.filter { $0 != account.emailAddress }
            }

            let subject = originalEmail.subject.hasPrefix("Re:") ? originalEmail.subject : "Re: \(originalEmail.subject)"

            return (toAddresses, ccAddresses, subject, originalEmail.messageId, originalEmail.references)
        }

        let outgoingEmail = OutgoingEmail(
            toAddresses: toAddresses,
            ccAddresses: ccAddresses,
            bccAddresses: [],
            subject: subject,
            textBody: body,
            htmlBody: htmlBody,
            inReplyTo: inReplyTo,
            references: references
        )

        do {
            let smtpEmail = try createSMTPEmail(from: outgoingEmail)
            try await server.sendEmail(smtpEmail)
        } catch {
            throw SMTPError.sendFailed(error.localizedDescription)
        }
    }

    /// Forward an existing email
    func forwardEmail(_ originalEmail: Email, to recipients: [String], body: String? = nil) async throws {
        let server = try await ensureConnected()

        guard !recipients.isEmpty else {
            throw SMTPError.invalidRecipients
        }

        let (subject, forwardedBody) = await MainActor.run {
            let subject = originalEmail.subject.hasPrefix("Fwd:") ? originalEmail.subject : "Fwd: \(originalEmail.subject)"

            var forwardedBody = body ?? ""
            forwardedBody += "\n\n---------- Forwarded message ----------\n"
            forwardedBody += "From: \(originalEmail.fromAddress)\n"
            forwardedBody += "Date: \(originalEmail.date.formatted())\n"
            forwardedBody += "Subject: \(originalEmail.subject)\n"
            forwardedBody += "To: \(originalEmail.toAddresses.joined(separator: ", "))\n\n"
            forwardedBody += originalEmail.textBody ?? ""

            return (subject, forwardedBody)
        }

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
        let senderName = account.displayName ?? account.name
        let sender = SwiftMail.EmailAddress(name: senderName, address: account.emailAddress)

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

    init(
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
