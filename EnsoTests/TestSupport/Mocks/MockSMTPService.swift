//
//  MockSMTPService.swift
//  EnsoTests
//

import Foundation
@testable import Enso

/// Mock implementation of SMTPServiceProtocol for testing
actor MockSMTPService: SMTPServiceProtocol {

    // MARK: - State

    private(set) var isConnected: Bool = false

    // MARK: - Tracking

    private(set) var connectCallCount = 0
    private(set) var disconnectCallCount = 0
    private(set) var sendEmailCallCount = 0
    private(set) var sendReplyCallCount = 0
    private(set) var forwardEmailCallCount = 0

    private(set) var sentEmails: [OutgoingEmail] = []
    private(set) var sentReplies: [(original: Email, body: String, htmlBody: String?, replyAll: Bool)] = []
    private(set) var forwardedEmails: [(original: Email, recipients: [String], body: String?)] = []

    private(set) var lastSentEmail: OutgoingEmail?
    private(set) var lastReplyOriginalEmail: Email?
    private(set) var lastForwardOriginalEmail: Email?

    // MARK: - Error Injection

    var shouldThrowOnConnect: SMTPService.SMTPError?
    var shouldThrowOnSend: SMTPService.SMTPError?
    var shouldThrowOnReply: SMTPService.SMTPError?
    var shouldThrowOnForward: SMTPService.SMTPError?

    // MARK: - Protocol Implementation

    func connect() async throws {
        connectCallCount += 1

        if let error = shouldThrowOnConnect {
            throw error
        }

        isConnected = true
    }

    func disconnect() async {
        disconnectCallCount += 1
        isConnected = false
    }

    func sendEmail(_ email: OutgoingEmail) async throws {
        sendEmailCallCount += 1
        lastSentEmail = email

        if let error = shouldThrowOnSend {
            throw error
        }

        sentEmails.append(email)
    }

    func sendReply(to originalEmail: Email, body: String, htmlBody: String?, replyAll: Bool) async throws {
        sendReplyCallCount += 1
        lastReplyOriginalEmail = originalEmail

        if let error = shouldThrowOnReply {
            throw error
        }

        sentReplies.append((original: originalEmail, body: body, htmlBody: htmlBody, replyAll: replyAll))
    }

    func forwardEmail(_ originalEmail: Email, to recipients: [String], body: String?) async throws {
        forwardEmailCallCount += 1
        lastForwardOriginalEmail = originalEmail

        if let error = shouldThrowOnForward {
            throw error
        }

        forwardedEmails.append((original: originalEmail, recipients: recipients, body: body))
    }

    // MARK: - Test Helpers

    /// Reset all state
    func reset() {
        isConnected = false

        connectCallCount = 0
        disconnectCallCount = 0
        sendEmailCallCount = 0
        sendReplyCallCount = 0
        forwardEmailCallCount = 0

        sentEmails = []
        sentReplies = []
        forwardedEmails = []

        lastSentEmail = nil
        lastReplyOriginalEmail = nil
        lastForwardOriginalEmail = nil

        shouldThrowOnConnect = nil
        shouldThrowOnSend = nil
        shouldThrowOnReply = nil
        shouldThrowOnForward = nil
    }

    /// Simulate connection state
    func simulateConnected(_ connected: Bool) {
        isConnected = connected
    }

    /// Check if a specific email was sent
    func wasSent(to address: String) -> Bool {
        sentEmails.contains { email in
            email.toAddresses.contains(address) ||
            email.ccAddresses.contains(address) ||
            email.bccAddresses.contains(address)
        }
    }

    /// Check if a reply was sent to specific email
    func wasReplySent(toMessageId messageId: String?) -> Bool {
        sentReplies.contains { $0.original.messageId == messageId }
    }

    /// Get all recipients that received emails
    var allRecipients: [String] {
        sentEmails.flatMap { $0.toAddresses + $0.ccAddresses + $0.bccAddresses }
    }

    /// Get total number of emails sent (including replies and forwards)
    var totalEmailsSent: Int {
        sentEmails.count + sentReplies.count + forwardedEmails.count
    }
}
