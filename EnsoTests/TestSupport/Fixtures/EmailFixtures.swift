//
//  EmailFixtures.swift
//  EnsoTests
//

import Foundation
@testable import Enso

/// Factory for creating Email test fixtures
enum EmailFixtures {

    // MARK: - Basic Factory

    /// Create a test email with customizable properties
    static func createEmail(
        uid: UInt32 = 1,
        messageId: String? = nil,
        subject: String = "Test Subject",
        fromAddress: String = "sender@example.com",
        fromName: String? = "Test Sender",
        toAddresses: [String] = ["recipient@example.com"],
        ccAddresses: [String] = [],
        bccAddresses: [String] = [],
        date: Date = Date(),
        textBody: String? = "This is the plain text body of the email.",
        htmlBody: String? = nil,
        snippet: String? = nil,
        isRead: Bool = false,
        isStarred: Bool = false,
        isDraft: Bool = false,
        isDeleted: Bool = false,
        hasAttachments: Bool = false,
        threadId: String? = nil,
        inReplyTo: String? = nil,
        references: [String] = []
    ) -> Email {
        let resolvedMessageId = messageId ?? "<\(UUID().uuidString)@example.com>"
        let email = Email(
            uid: uid,
            subject: subject,
            fromAddress: fromAddress,
            fromName: fromName,
            date: date
        )
        email.messageId = resolvedMessageId
        email.toAddresses = toAddresses
        email.ccAddresses = ccAddresses
        email.bccAddresses = bccAddresses
        email.textBody = textBody
        email.htmlBody = htmlBody
        email.snippet = snippet
        email.isRead = isRead
        email.isStarred = isStarred
        email.isDraft = isDraft
        email.isDeleted = isDeleted
        email.hasAttachments = hasAttachments
        email.threadId = threadId
        email.inReplyTo = inReplyTo
        email.references = references
        return email
    }

    // MARK: - Common Variations

    /// Create an unread email
    static func createUnreadEmail(
        uid: UInt32 = 1,
        subject: String = "Unread Email"
    ) -> Email {
        createEmail(uid: uid, subject: subject, isRead: false)
    }

    /// Create a read email
    static func createReadEmail(
        uid: UInt32 = 1,
        subject: String = "Read Email"
    ) -> Email {
        createEmail(uid: uid, subject: subject, isRead: true)
    }

    /// Create a starred email
    static func createStarredEmail(
        uid: UInt32 = 1,
        subject: String = "Important Email"
    ) -> Email {
        createEmail(uid: uid, subject: subject, isStarred: true)
    }

    /// Create a draft email
    static func createDraftEmail(
        uid: UInt32 = 1,
        subject: String = "Draft Email"
    ) -> Email {
        createEmail(uid: uid, subject: subject, isDraft: true)
    }

    /// Create an email with attachments
    static func createEmailWithAttachments(
        uid: UInt32 = 1,
        subject: String = "Email with Attachments"
    ) -> Email {
        createEmail(uid: uid, subject: subject, hasAttachments: true)
    }

    // MARK: - Content Variations

    /// Create an email with HTML body only
    static func createHTMLOnlyEmail(
        uid: UInt32 = 1,
        subject: String = "HTML Email"
    ) -> Email {
        createEmail(
            uid: uid,
            subject: subject,
            textBody: nil,
            htmlBody: "<html><body><p>This is an <strong>HTML</strong> email.</p></body></html>"
        )
    }

    /// Create an email with both text and HTML body
    static func createMultipartEmail(
        uid: UInt32 = 1,
        subject: String = "Multipart Email"
    ) -> Email {
        createEmail(
            uid: uid,
            subject: subject,
            textBody: "This is the plain text version.",
            htmlBody: "<html><body><p>This is the <strong>HTML</strong> version.</p></body></html>"
        )
    }

    /// Create an email with no body
    static func createEmptyBodyEmail(
        uid: UInt32 = 1,
        subject: String = "Empty Body Email"
    ) -> Email {
        createEmail(uid: uid, subject: subject, textBody: nil, htmlBody: nil)
    }

    /// Create an email with a long body
    static func createLongBodyEmail(
        uid: UInt32 = 1,
        subject: String = "Long Email"
    ) -> Email {
        let longText = String(repeating: "This is a paragraph of text. ", count: 100)
        return createEmail(uid: uid, subject: subject, textBody: longText)
    }

    /// Create an email with a snippet
    static func createEmailWithSnippet(
        uid: UInt32 = 1,
        subject: String = "Email with Snippet",
        snippet: String = "This is the preview snippet..."
    ) -> Email {
        createEmail(uid: uid, subject: subject, snippet: snippet)
    }

    // MARK: - Sender Variations

    /// Create an email with no sender name (address only)
    static func createEmailWithoutSenderName(
        uid: UInt32 = 1,
        fromAddress: String = "unknown@example.com"
    ) -> Email {
        createEmail(uid: uid, fromAddress: fromAddress, fromName: nil)
    }

    /// Create an email from a specific sender
    static func createEmailFrom(
        senderName: String,
        senderAddress: String,
        uid: UInt32 = 1
    ) -> Email {
        createEmail(uid: uid, fromAddress: senderAddress, fromName: senderName)
    }

    // MARK: - Thread Variations

    /// Create an email thread with multiple messages
    static func createEmailThread(
        count: Int = 3,
        subject: String = "Thread Subject"
    ) -> [Email] {
        let threadId = UUID().uuidString
        var previousMessageId: String? = nil
        var references: [String] = []
        var emails: [Email] = []

        for index in 1...count {
            let messageId = "<thread-\(index)@example.com>"
            let subjectLine = index == 1 ? subject : "Re: \(subject)"
            let senderAddress = index % 2 == 0 ? "other@example.com" : "sender@example.com"
            let senderName = index % 2 == 0 ? "Other Person" : "Original Sender"
            let sentDate = Date().addingTimeInterval(Double(index) * 3600)
            let body = "This is message \(index) in the thread."
            let email = createEmail(
                uid: UInt32(index),
                messageId: messageId,
                subject: subjectLine,
                fromAddress: senderAddress,
                fromName: senderName,
                date: sentDate,
                textBody: body,
                threadId: threadId,
                inReplyTo: previousMessageId,
                references: references
            )

            references.append(messageId)
            previousMessageId = messageId

            emails.append(email)
        }

        return emails
    }

    /// Create a reply email
    static func createReplyEmail(
        to originalEmail: Email,
        uid: UInt32 = 100
    ) -> Email {
        var refs = originalEmail.references
        if let msgId = originalEmail.messageId {
            refs.append(msgId)
        }

        return createEmail(
            uid: uid,
            subject: "Re: \(originalEmail.subject)",
            fromAddress: "replier@example.com",
            fromName: "Replier",
            toAddresses: [originalEmail.fromAddress],
            date: Date(),
            textBody: "This is a reply.",
            threadId: originalEmail.threadId,
            inReplyTo: originalEmail.messageId,
            references: refs
        )
    }

    // MARK: - Batch Creation

    /// Create multiple emails
    static func createMultipleEmails(
        count: Int = 10,
        startUid: UInt32 = 1
    ) -> [Email] {
        var emails: [Email] = []

        for index in 0..<count {
            let uid = startUid + UInt32(index)
            let date = Date().addingTimeInterval(Double(-index) * 3600) // Newer first
            let email = createEmail(
                uid: uid,
                subject: "Email \(uid)",
                date: date
            )
            emails.append(email)
        }

        return emails
    }

    /// Create emails with mixed read/unread status
    static func createMixedStatusEmails(count: Int = 10) -> [Email] {
        var emails: [Email] = []

        for index in 0..<count {
            let email = createEmail(
                uid: UInt32(index + 1),
                subject: "Email \(index + 1)",
                isRead: index % 2 == 0,
                isStarred: index % 3 == 0
            )
            emails.append(email)
        }

        return emails
    }
}
