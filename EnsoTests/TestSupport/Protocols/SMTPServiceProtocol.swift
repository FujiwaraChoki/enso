//
//  SMTPServiceProtocol.swift
//  EnsoTests
//

import Foundation
@testable import Enso

/// Protocol for SMTPService to enable testing with mocks
protocol SMTPServiceProtocol: Actor {
    /// Connect to the SMTP server
    func connect() async throws

    /// Disconnect from the SMTP server
    func disconnect() async

    /// Send an email
    func sendEmail(_ email: OutgoingEmail) async throws

    /// Send a reply to an existing email
    func sendReply(to originalEmail: Email, body: String, htmlBody: String?, replyAll: Bool) async throws

    /// Forward an existing email
    func forwardEmail(_ originalEmail: Email, to recipients: [String], body: String?) async throws
}
