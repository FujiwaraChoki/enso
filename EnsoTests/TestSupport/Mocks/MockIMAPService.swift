//
//  MockIMAPService.swift
//  EnsoTests
//

import Foundation
@testable import Enso

/// Mock implementation of IMAPServiceProtocol for testing
actor MockIMAPService: IMAPServiceProtocol {

    // MARK: - State

    private(set) var _isConnected: Bool = false
    var isConnected: Bool { _isConnected }

    // MARK: - Configurable Responses

    var mailboxes: [MailboxInfoResult] = []
    var mailboxStatus: MailboxStatusResult?
    var messageInfos: [MessageInfoResult] = []
    var fetchedMessages: [UInt32: FetchedMessage] = [:]
    var searchResults: [UInt32] = []
    var idleEvents: [IMAPEvent] = []

    // MARK: - Tracking

    private(set) var connectCallCount = 0
    private(set) var disconnectCallCount = 0
    private(set) var listMailboxesCallCount = 0
    private(set) var selectMailboxCallCount = 0
    private(set) var fetchMessageInfosCallCount = 0
    private(set) var fetchMessageCallCount = 0
    private(set) var searchCallCount = 0

    private(set) var lastSelectedMailbox: String?
    private(set) var lastFetchedMailbox: String?
    private(set) var lastFetchedUid: UInt32?
    private(set) var lastSearchCriteria: [SearchCriteriaWrapper] = []

    private(set) var markedAsReadUIDs: [UInt32] = []
    private(set) var markedAsUnreadUIDs: [UInt32] = []
    private(set) var starredUIDs: [UInt32] = []
    private(set) var unstarredUIDs: [UInt32] = []
    private(set) var movedMessages: [(uids: [UInt32], from: String, to: String)] = []
    private(set) var deletedMessages: [(uids: [UInt32], mailbox: String, trashFolder: String)] = []

    // MARK: - Error Injection

    var shouldThrowOnConnect: IMAPService.IMAPError?
    var shouldThrowOnListMailboxes: IMAPService.IMAPError?
    var shouldThrowOnSelectMailbox: IMAPService.IMAPError?
    var shouldThrowOnFetchMessageInfos: IMAPService.IMAPError?
    var shouldThrowOnFetchMessage: IMAPService.IMAPError?
    var shouldThrowOnSearch: IMAPService.IMAPError?
    var shouldThrowOnFlagOperation: IMAPService.IMAPError?
    var shouldThrowOnMove: IMAPService.IMAPError?

    // MARK: - Protocol Implementation

    func connect() async throws {
        connectCallCount += 1

        if let error = shouldThrowOnConnect {
            throw error
        }

        _isConnected = true
    }

    func disconnect() async {
        disconnectCallCount += 1
        _isConnected = false
    }

    func stopIdle() async {
        // No-op in mock
    }

    func listMailboxes() async throws -> [MailboxInfoResult] {
        listMailboxesCallCount += 1

        if let error = shouldThrowOnListMailboxes {
            throw error
        }

        return mailboxes
    }

    func selectMailbox(_ path: String) async throws -> MailboxStatusResult {
        selectMailboxCallCount += 1
        lastSelectedMailbox = path

        if let error = shouldThrowOnSelectMailbox {
            throw error
        }

        guard let status = mailboxStatus else {
            throw IMAPService.IMAPError.mailboxNotFound(path)
        }

        return status
    }

    func fetchMessageInfos(mailbox: String, range: ClosedRange<Int>?) async throws -> [MessageInfoResult] {
        fetchMessageInfosCallCount += 1
        lastFetchedMailbox = mailbox

        if let error = shouldThrowOnFetchMessageInfos {
            throw error
        }

        return messageInfos
    }

    func fetchMessage(mailbox: String, uid: UInt32) async throws -> FetchedMessage {
        fetchMessageCallCount += 1
        lastFetchedMailbox = mailbox
        lastFetchedUid = uid

        if let error = shouldThrowOnFetchMessage {
            throw error
        }

        guard let message = fetchedMessages[uid] else {
            throw IMAPService.IMAPError.messageFetchFailed
        }

        return message
    }

    func search(mailbox: String, criteria: [SearchCriteriaWrapper]) async throws -> [UInt32] {
        searchCallCount += 1
        lastSearchCriteria = criteria

        if let error = shouldThrowOnSearch {
            throw error
        }

        return searchResults
    }

    func markAsRead(mailbox: String, uids: [UInt32]) async throws {
        if let error = shouldThrowOnFlagOperation {
            throw error
        }
        markedAsReadUIDs.append(contentsOf: uids)
    }

    func markAsUnread(mailbox: String, uids: [UInt32]) async throws {
        if let error = shouldThrowOnFlagOperation {
            throw error
        }
        markedAsUnreadUIDs.append(contentsOf: uids)
    }

    func star(mailbox: String, uids: [UInt32]) async throws {
        if let error = shouldThrowOnFlagOperation {
            throw error
        }
        starredUIDs.append(contentsOf: uids)
    }

    func unstar(mailbox: String, uids: [UInt32]) async throws {
        if let error = shouldThrowOnFlagOperation {
            throw error
        }
        unstarredUIDs.append(contentsOf: uids)
    }

    func move(mailbox: String, uids: [UInt32], to destination: String) async throws {
        if let error = shouldThrowOnMove {
            throw error
        }
        movedMessages.append((uids: uids, from: mailbox, to: destination))
    }

    func delete(mailbox: String, uids: [UInt32], trashFolder: String) async throws {
        if let error = shouldThrowOnMove {
            throw error
        }
        deletedMessages.append((uids: uids, mailbox: mailbox, trashFolder: trashFolder))
        try await move(mailbox: mailbox, uids: uids, to: trashFolder)
    }

    func startIdle(mailbox: String) async throws -> AsyncStream<IMAPEvent> {
        AsyncStream { continuation in
            for event in self.idleEvents {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    // MARK: - Test Helpers

    /// Reset all state
    func reset() {
        _isConnected = false
        mailboxes = []
        mailboxStatus = nil
        messageInfos = []
        fetchedMessages = [:]
        searchResults = []
        idleEvents = []

        connectCallCount = 0
        disconnectCallCount = 0
        listMailboxesCallCount = 0
        selectMailboxCallCount = 0
        fetchMessageInfosCallCount = 0
        fetchMessageCallCount = 0
        searchCallCount = 0

        lastSelectedMailbox = nil
        lastFetchedMailbox = nil
        lastFetchedUid = nil
        lastSearchCriteria = []

        markedAsReadUIDs = []
        markedAsUnreadUIDs = []
        starredUIDs = []
        unstarredUIDs = []
        movedMessages = []
        deletedMessages = []

        shouldThrowOnConnect = nil
        shouldThrowOnListMailboxes = nil
        shouldThrowOnSelectMailbox = nil
        shouldThrowOnFetchMessageInfos = nil
        shouldThrowOnFetchMessage = nil
        shouldThrowOnSearch = nil
        shouldThrowOnFlagOperation = nil
        shouldThrowOnMove = nil
    }

    /// Set up standard mailboxes
    func setupStandardMailboxes() {
        mailboxes = [
            MailboxInfoResult(name: "INBOX", path: "INBOX", delimiter: "/", isSelectable: true, specialUse: .inbox),
            MailboxInfoResult(name: "Sent", path: "Sent", delimiter: "/", isSelectable: true, specialUse: .sent),
            MailboxInfoResult(name: "Drafts", path: "Drafts", delimiter: "/", isSelectable: true, specialUse: .drafts),
            MailboxInfoResult(name: "Trash", path: "Trash", delimiter: "/", isSelectable: true, specialUse: .trash)
        ]

        mailboxStatus = MailboxStatusResult(
            messageCount: 100,
            recentCount: 5,
            firstUnseen: 95,
            uidValidity: 12345,
            uidNext: 101
        )
    }

    /// Simulate connection state
    func simulateConnected(_ connected: Bool) {
        _isConnected = connected
    }
}
