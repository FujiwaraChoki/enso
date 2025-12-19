//
//  IMAPService.swift
//  Enso
//

import Foundation
import SwiftMail
import SwiftData
import NIOIMAPCore

/// Service for IMAP email operations using SwiftMail
actor IMAPService {

    // MARK: - Types

    enum IMAPError: LocalizedError {
        case notConnected
        case authenticationFailed
        case mailboxNotFound(String)
        case messageFetchFailed
        case connectionFailed(Error)
        case operationFailed(Error)

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Not connected to IMAP server"
            case .authenticationFailed:
                return "Authentication failed. Check your credentials."
            case .mailboxNotFound(let name):
                return "Mailbox '\(name)' not found"
            case .messageFetchFailed:
                return "Failed to fetch message"
            case .connectionFailed(let error):
                return "Connection failed: \(error.localizedDescription)"
            case .operationFailed(let error):
                return "Operation failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    private var server: SwiftMail.IMAPServer?
    private let account: Account
    private let keychainService: KeychainService
    private var isConnecting: Bool = false
    private var isIdling: Bool = false

    var isConnected: Bool {
        server != nil
    }

    // MARK: - Initialization

    init(account: Account, keychainService: KeychainService = .shared) {
        self.account = account
        self.keychainService = keychainService
    }

    // MARK: - Connection

    /// Connect and authenticate with the IMAP server
    /// This method is idempotent - if already connected, it returns immediately
    func connect() async throws {
        // Already connected, nothing to do
        if isConnected {
            return
        }

        // Prevent concurrent connection attempts
        guard !isConnecting else {
            // Wait a bit and check again
            try await Task.sleep(for: .milliseconds(100))
            if isConnected {
                return
            }
            throw IMAPError.connectionFailed(NSError(domain: "IMAPService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection already in progress"]))
        }

        isConnecting = true
        defer { isConnecting = false }

        do {
            let newServer = SwiftMail.IMAPServer(host: account.imapHost, port: account.imapPort)
            try await newServer.connect()

            // Get password from keychain
            let password = try await keychainService.getCredentials(for: account)
            try await newServer.login(username: account.emailAddress, password: password)

            self.server = newServer
        } catch is KeychainService.KeychainError {
            throw IMAPError.authenticationFailed
        } catch {
            throw IMAPError.connectionFailed(error)
        }
    }

    /// Disconnect from the IMAP server
    func disconnect() async {
        isIdling = false
        if let server = server {
            try? await server.disconnect()
        }
        server = nil
    }

    /// Stop IDLE mode if active (must be called before other operations)
    func stopIdle() async {
        isIdling = false
    }

    /// Ensure we're connected and not in IDLE mode before operations
    private func ensureConnected() async throws -> SwiftMail.IMAPServer {
        guard let server = server else {
            throw IMAPError.notConnected
        }
        // Cannot perform operations while IDLE is active
        if isIdling {
            throw IMAPError.operationFailed(NSError(domain: "IMAPService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot perform operation while IDLE is active. Stop IDLE first."]))
        }
        return server
    }

    // MARK: - Mailbox Operations

    /// List all mailboxes for the account
    func listMailboxes() async throws -> [MailboxInfoResult] {
        let server = try await ensureConnected()

        do {
            let mailboxes = try await server.listMailboxes()
            return mailboxes.map { mailboxInfo in
                MailboxInfoResult(
                    name: mailboxInfo.name,
                    path: mailboxInfo.name,
                    delimiter: mailboxInfo.hierarchyDelimiter.map { String($0) } ?? "/",
                    isSelectable: mailboxInfo.isSelectable,
                    specialUse: detectSpecialUse(from: mailboxInfo)
                )
            }
        } catch {
            throw IMAPError.operationFailed(error)
        }
    }

    /// Select a mailbox and return its status
    func selectMailbox(_ path: String) async throws -> MailboxStatusResult {
        let server = try await ensureConnected()

        do {
            let status = try await server.selectMailbox(path)
            return MailboxStatusResult(
                messageCount: status.messageCount,
                recentCount: status.recentCount,
                firstUnseen: status.firstUnseen,
                uidValidity: status.uidValidity,
                uidNext: status.uidNext.value
            )
        } catch {
            throw IMAPError.mailboxNotFound(path)
        }
    }

    // MARK: - Message Operations

    /// Fetch message headers/info for a range of UIDs
    func fetchMessageInfos(mailbox: String, range: ClosedRange<Int>? = nil) async throws -> [MessageInfoResult] {
        let server = try await ensureConnected()

        do {
            _ = try await server.selectMailbox(mailbox)

            // Build UID set - if no range, fetch all messages
            let uidSet: SwiftMail.UIDSet
            if let range = range {
                uidSet = SwiftMail.UIDSet(range)
            } else {
                // Fetch all messages
                uidSet = SwiftMail.UIDSet(1...)
            }

            var results: [MessageInfoResult] = []

            let stream = server.fetchMessageInfos(using: uidSet)
            for try await info in stream {
                let mappedInfo = await MainActor.run {
                    MessageInfoResult(from: info)
                }
                results.append(mappedInfo)
            }

            return results
        } catch {
            throw IMAPError.operationFailed(error)
        }
    }

    /// Fetch a complete message by UID
    func fetchMessage(mailbox: String, uid: UInt32) async throws -> FetchedMessage {
        let server = try await ensureConnected()

        do {
            _ = try await server.selectMailbox(mailbox)

            let uidSet = SwiftMail.UIDSet(Int(uid)...Int(uid))
            let stream = server.fetchMessageInfos(using: uidSet)

            var messageInfo: SwiftMail.MessageInfo?
            for try await info in stream {
                messageInfo = info
                break
            }

            guard let info = messageInfo else {
                throw IMAPError.messageFetchFailed
            }

            let message = try await server.fetchMessage(from: info)
            return await MainActor.run {
                FetchedMessage(from: message)
            }
        } catch let error as IMAPError {
            throw error
        } catch {
            throw IMAPError.operationFailed(error)
        }
    }

    /// Search messages in a mailbox
    func search(mailbox: String, criteria: [SwiftMail.SearchCriteria]) async throws -> [UInt32] {
        let server = try await ensureConnected()

        do {
            _ = try await server.selectMailbox(mailbox)
            let results: SwiftMail.UIDSet = try await server.search(criteria: criteria)
            // Expand ranges to individual UIDs
            var uids: [UInt32] = []
            for range in results.ranges {
                for uid in range {
                    uids.append(UInt32(uid))
                }
            }
            return uids
        } catch {
            throw IMAPError.operationFailed(error)
        }
    }

    // MARK: - Flag Operations

    /// Mark messages as read
    func markAsRead(mailbox: String, uids: [UInt32]) async throws {
        try await setFlags(mailbox: mailbox, uids: uids, flags: [SwiftMail.Flag.seen], add: true)
    }

    /// Mark messages as unread
    func markAsUnread(mailbox: String, uids: [UInt32]) async throws {
        try await setFlags(mailbox: mailbox, uids: uids, flags: [SwiftMail.Flag.seen], add: false)
    }

    /// Star/flag messages
    func star(mailbox: String, uids: [UInt32]) async throws {
        try await setFlags(mailbox: mailbox, uids: uids, flags: [SwiftMail.Flag.flagged], add: true)
    }

    /// Unstar/unflag messages
    func unstar(mailbox: String, uids: [UInt32]) async throws {
        try await setFlags(mailbox: mailbox, uids: uids, flags: [SwiftMail.Flag.flagged], add: false)
    }

    /// Set or remove flags on messages
    private func setFlags(mailbox: String, uids: [UInt32], flags: [SwiftMail.Flag], add: Bool) async throws {
        let server = try await ensureConnected()

        do {
            _ = try await server.selectMailbox(mailbox)

            guard let min = uids.min(), let max = uids.max() else { return }
            let uidSet = SwiftMail.UIDSet(Int(min)...Int(max))

            let operation: NIOIMAPCore.StoreOperation = add ? .add : .remove
            try await server.store(
                flags: flags,
                on: uidSet,
                operation: operation
            )
        } catch {
            throw IMAPError.operationFailed(error)
        }
    }

    // MARK: - Move/Copy Operations

    /// Move messages to another folder
    func move(mailbox: String, uids: [UInt32], to destination: String) async throws {
        let server = try await ensureConnected()

        do {
            _ = try await server.selectMailbox(mailbox)

            guard let min = uids.min(), let max = uids.max() else { return }
            let uidSet = SwiftMail.UIDSet(Int(min)...Int(max))

            try await server.move(messages: uidSet, to: destination)
        } catch {
            throw IMAPError.operationFailed(error)
        }
    }

    /// Delete messages (move to trash)
    func delete(mailbox: String, uids: [UInt32], trashFolder: String = "Trash") async throws {
        try await move(mailbox: mailbox, uids: uids, to: trashFolder)
    }

    // MARK: - IDLE (Real-time Updates)

    /// Start IDLE mode for real-time updates
    /// Important: While IDLE is active, no other mailbox operations can be performed
    func startIdle(mailbox: String) async throws -> AsyncStream<IMAPEvent> {
        guard let server = server else {
            throw IMAPError.notConnected
        }

        // Cannot start IDLE if already idling
        guard !isIdling else {
            throw IMAPError.operationFailed(NSError(domain: "IMAPService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Already in IDLE mode"]))
        }

        do {
            _ = try await server.selectMailbox(mailbox)
            isIdling = true

            return AsyncStream { [weak self] continuation in
                Task { [weak self] in
                    do {
                        let stream = try await server.idle()
                        for await event in stream {
                            // Check if we should stop
                            guard let self = self, await self.isIdling else {
                                continuation.finish()
                                return
                            }
                            let mappedEvent = await MainActor.run {
                                IMAPEvent(from: event)
                            }
                            continuation.yield(mappedEvent)
                        }
                        await self?.markIdleEnded()
                        continuation.finish()
                    } catch {
                        await self?.markIdleEnded()
                        continuation.finish()
                    }
                }
            }
        } catch {
            isIdling = false
            throw IMAPError.operationFailed(error)
        }
    }

    /// Mark IDLE as ended (internal helper)
    private func markIdleEnded() {
        isIdling = false
    }

    // MARK: - Helper Methods

    /// Detect special use folder type from mailbox info
    private func detectSpecialUse(from mailboxInfo: SwiftMail.Mailbox.Info) -> FolderType? {
        let name = mailboxInfo.name.lowercased()
        let attributes = mailboxInfo.attributes

        // First check special-use attributes
        if attributes.contains(.inbox) { return .inbox }
        if attributes.contains(.sent) { return .sent }
        if attributes.contains(.drafts) { return .drafts }
        if attributes.contains(.trash) { return .trash }
        if attributes.contains(.junk) { return .spam }
        if attributes.contains(.archive) { return .archive }

        // Fallback to name-based detection
        if name == "inbox" { return .inbox }
        if name.contains("sent") { return .sent }
        if name.contains("draft") { return .drafts }
        if name.contains("trash") || name.contains("deleted") { return .trash }
        if name.contains("spam") || name.contains("junk") { return .spam }
        if name.contains("archive") { return .archive }
        if name == "all mail" || name == "[gmail]/all mail" { return .all }

        return .custom
    }
}

// MARK: - Result Types

/// Mailbox information
struct MailboxInfoResult: Sendable {
    let name: String
    let path: String
    let delimiter: String
    let isSelectable: Bool
    let specialUse: FolderType?
}

/// Mailbox status after selection
struct MailboxStatusResult: Sendable {
    let messageCount: Int
    let recentCount: Int
    let firstUnseen: Int
    let uidValidity: UInt32
    let uidNext: UInt32
}

/// Message info/headers result
struct MessageInfoResult: Sendable {
    let uid: UInt32?
    let sequenceNumber: UInt32
    let messageId: String?
    let subject: String
    let fromAddress: String
    let toAddresses: [String]
    let ccAddresses: [String]
    let date: Date
    let flags: MessageFlagsResult
    let hasAttachments: Bool

    init(from info: SwiftMail.MessageInfo) {
        self.uid = info.uid?.value
        self.sequenceNumber = info.sequenceNumber.value
        self.messageId = info.messageId
        self.subject = info.subject ?? "(No Subject)"
        self.fromAddress = info.from ?? ""
        self.toAddresses = info.to
        self.ccAddresses = info.cc
        self.date = info.date ?? Date()
        self.flags = MessageFlagsResult(from: info.flags)

        // Check if any part is an attachment
        self.hasAttachments = info.parts.contains { part in
            (part.disposition?.lowercased() == "attachment") ||
            (part.filename != nil && !part.filename!.isEmpty && part.contentId == nil)
        }
    }
}

/// Message flags
struct MessageFlagsResult: Sendable {
    let isSeen: Bool
    let isFlagged: Bool
    let isAnswered: Bool
    let isDraft: Bool
    let isDeleted: Bool

    init(from flags: [SwiftMail.Flag]) {
        self.isSeen = flags.contains(.seen)
        self.isFlagged = flags.contains(.flagged)
        self.isAnswered = flags.contains(.answered)
        self.isDraft = flags.contains(.draft)
        self.isDeleted = flags.contains(.deleted)
    }
}

/// Complete fetched message
struct FetchedMessage: Sendable {
    let uid: UInt32?
    let sequenceNumber: UInt32
    let messageId: String?
    let subject: String
    let fromAddress: String
    let toAddresses: [String]
    let ccAddresses: [String]
    let bccAddresses: [String]
    let date: Date
    let textBody: String?
    let htmlBody: String?
    let attachments: [AttachmentInfoResult]
    let flags: MessageFlagsResult

    init(from message: SwiftMail.Message) {
        self.uid = message.uid?.value
        self.sequenceNumber = message.sequenceNumber.value
        self.messageId = message.header.messageId
        self.subject = message.subject ?? "(No Subject)"
        self.fromAddress = message.from ?? ""
        self.toAddresses = message.to
        self.ccAddresses = message.cc
        self.bccAddresses = message.bcc
        self.date = message.date ?? Date()
        self.flags = MessageFlagsResult(from: message.flags)

        // Extract body content
        self.textBody = message.textBody
        self.htmlBody = message.htmlBody

        // Extract attachments
        self.attachments = message.attachments.map { part in
            AttachmentInfoResult(
                filename: part.filename ?? part.suggestedFilename,
                mimeType: part.contentType,
                size: Int64(part.data?.count ?? 0),
                contentId: part.contentId,
                isInline: part.disposition?.lowercased() == "inline"
            )
        }
    }
}

/// Attachment info
struct AttachmentInfoResult: Sendable {
    let filename: String
    let mimeType: String
    let size: Int64
    let contentId: String?
    let isInline: Bool
}

/// IMAP events for IDLE
enum IMAPEvent: Sendable {
    case newMessages(count: Int)
    case expunge(sequenceNumber: UInt32)
    case flagsChanged
    case connectionLost

    init(from event: SwiftMail.IMAPServerEvent) {
        switch event {
        case .exists(let count):
            self = .newMessages(count: Int(count))
        case .expunge(let seqNum):
            self = .expunge(sequenceNumber: seqNum.value)
        default:
            self = .connectionLost
        }
    }
}
