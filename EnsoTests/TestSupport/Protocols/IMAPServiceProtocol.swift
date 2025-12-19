//
//  IMAPServiceProtocol.swift
//  EnsoTests
//

import Foundation
@testable import Enso

/// Protocol for IMAPService to enable testing with mocks
protocol IMAPServiceProtocol: Actor {
    /// Whether the service is currently connected
    var isConnected: Bool { get }

    /// Connect to the IMAP server
    func connect() async throws

    /// Disconnect from the IMAP server
    func disconnect() async

    /// Stop IDLE mode if active
    func stopIdle() async

    /// List all mailboxes for the account
    func listMailboxes() async throws -> [MailboxInfoResult]

    /// Select a mailbox and return its status
    func selectMailbox(_ path: String) async throws -> MailboxStatusResult

    /// Fetch message headers/info for a range of UIDs
    func fetchMessageInfos(mailbox: String, range: ClosedRange<Int>?) async throws -> [MessageInfoResult]

    /// Fetch a complete message by UID
    func fetchMessage(mailbox: String, uid: UInt32) async throws -> FetchedMessage

    /// Search messages in a mailbox
    func search(mailbox: String, criteria: [SearchCriteriaWrapper]) async throws -> [UInt32]

    /// Mark messages as read
    func markAsRead(mailbox: String, uids: [UInt32]) async throws

    /// Mark messages as unread
    func markAsUnread(mailbox: String, uids: [UInt32]) async throws

    /// Star/flag messages
    func star(mailbox: String, uids: [UInt32]) async throws

    /// Unstar/unflag messages
    func unstar(mailbox: String, uids: [UInt32]) async throws

    /// Move messages to another folder
    func move(mailbox: String, uids: [UInt32], to destination: String) async throws

    /// Delete messages (move to trash)
    func delete(mailbox: String, uids: [UInt32], trashFolder: String) async throws

    /// Start IDLE mode for real-time updates
    func startIdle(mailbox: String) async throws -> AsyncStream<IMAPEvent>
}

/// Wrapper for search criteria to avoid SwiftMail dependency in protocol
enum SearchCriteriaWrapper: Sendable {
    case all
    case from(String)
    case subject(String)
    case body(String)
    case unseen
    case seen
    case flagged
    case unflagged
    case since(Date)
    case before(Date)
}
