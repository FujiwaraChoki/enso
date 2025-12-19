//
//  SyncService.swift
//  Enso
//

import Foundation
import SwiftUI
import SwiftData
import SwiftMail

/// Service for synchronizing email data with IMAP servers
@MainActor
@Observable
final class SyncService {

    // MARK: - Types

    enum SyncError: LocalizedError {
        case noActiveAccount
        case syncFailed(Error)
        case modelContextRequired

        var errorDescription: String? {
            switch self {
            case .noActiveAccount:
                return "No active account available for sync"
            case .syncFailed(let error):
                return "Sync failed: \(error.localizedDescription)"
            case .modelContextRequired:
                return "Model context is required for sync operations"
            }
        }
    }

    enum SyncState: Equatable {
        case idle
        case syncing(progress: Double)
        case error(String)
    }

    // MARK: - Properties

    private(set) var syncState: SyncState = .idle
    private(set) var lastSyncDate: Date?

    /// Whether a background sync is currently in progress
    private(set) var isBackgroundSyncing = false

    private var imapServices: [UUID: IMAPService]
    private var activeSyncTasks: [UUID: Task<Void, Never>]
    private var idleTasks: [UUID: Task<Void, Never>]
    private var backgroundSyncTasks: [UUID: Task<Void, Never>]
    private var fetchingBodyForUIDs: Set<UInt32> = []

    private let keychainService: KeychainService

    /// Cache validity duration - skip sync if last sync was within this time
    private let cacheValidityDuration: TimeInterval = 5 * 60 // 5 minutes

    // MARK: - Initialization

    init(keychainService: KeychainService = .shared) {
        self.keychainService = keychainService
        self.imapServices = [:]
        self.activeSyncTasks = [:]
        self.idleTasks = [:]
        self.backgroundSyncTasks = [:]
    }

    // MARK: - Public Methods

    /// Perform a full sync for an account
    func syncAccount(_ account: Account, modelContext: ModelContext) async throws {
        guard account.isActive else { return }

        // Update state
        account.syncStatus = .syncing
        syncState = .syncing(progress: 0)

        do {
            // Get or create IMAP service
            let imapService = getOrCreateIMAPService(for: account)

            // Connect if needed
            try await imapService.connect()

            // Sync folders first
            try await syncFolders(for: account, using: imapService, modelContext: modelContext)
            syncState = .syncing(progress: 0.2)

            // Sync messages for each folder
            let folders = account.folders
            let folderCount = Double(folders.count)

            for (index, folder) in folders.enumerated() {
                if folder.isSelectable {
                    try await syncMessages(for: folder, using: imapService, modelContext: modelContext)
                }
                let progress = 0.2 + (0.8 * Double(index + 1) / max(folderCount, 1))
                syncState = .syncing(progress: progress)
            }

            // Update account status
            account.lastSyncDate = Date()
            account.syncStatus = .connected
            lastSyncDate = Date()
            syncState = .idle

            // Save changes
            try modelContext.save()

        } catch {
            account.syncStatus = .error
            syncState = .error(error.localizedDescription)
            throw SyncError.syncFailed(error)
        }
    }

    /// Sync only the inbox for quick refresh
    func syncInbox(for account: Account, modelContext: ModelContext) async throws {
        guard account.isActive else { return }

        let imapService = getOrCreateIMAPService(for: account)

        do {
            try await imapService.connect()

            if let inbox = account.folders.first(where: { $0.specialUse == .inbox }) {
                try await syncMessages(for: inbox, using: imapService, modelContext: modelContext)
            }

            account.lastSyncDate = Date()
            try modelContext.save()

        } catch {
            throw SyncError.syncFailed(error)
        }
    }

    /// Check if cache is still valid (recent sync exists)
    func isCacheValid(for account: Account) -> Bool {
        guard let lastSync = account.lastSyncDate else { return false }
        return Date().timeIntervalSince(lastSync) < cacheValidityDuration
    }

    /// Perform background sync without blocking UI - shows cached data immediately
    /// Returns immediately if cache is valid, otherwise syncs in background
    /// - Parameter startIdleAfter: If true, starts IDLE monitoring after sync completes
    func syncAccountInBackground(_ account: Account, modelContext: ModelContext, force: Bool = false, startIdleAfter: Bool = false) {
        guard account.isActive else { return }

        // Skip if cache is valid and not forced
        if !force && isCacheValid(for: account) {
            // Even if skipping sync, start IDLE if requested
            if startIdleAfter {
                startIdleMonitoring(for: account, modelContext: modelContext)
            }
            return
        }

        // Cancel any existing background sync for this account
        backgroundSyncTasks[account.id]?.cancel()

        // Also cancel IDLE to prevent concurrent IMAP operations
        idleTasks[account.id]?.cancel()

        isBackgroundSyncing = true

        backgroundSyncTasks[account.id] = Task { [weak self] in
            guard let self = self else { return }

            do {
                // Get or create IMAP service
                let imapService = self.getOrCreateIMAPService(for: account)

                // Connect if needed
                try await imapService.connect()

                // Sync folders first (quick operation)
                try await self.syncFolders(for: account, using: imapService, modelContext: modelContext)

                // Sync inbox first for immediate visibility
                if let inbox = account.folders.first(where: { $0.specialUse == .inbox }) {
                    try await self.syncMessages(for: inbox, using: imapService, modelContext: modelContext)
                    try modelContext.save()
                }

                // Then sync other folders in background
                let otherFolders = account.folders.filter { $0.specialUse != .inbox && $0.isSelectable }
                for folder in otherFolders {
                    if Task.isCancelled { break }
                    try await self.syncMessages(for: folder, using: imapService, modelContext: modelContext)
                }

                // Update account status
                account.lastSyncDate = Date()
                account.syncStatus = .connected
                self.lastSyncDate = Date()

                // Save changes
                try modelContext.save()

                // Disconnect before starting IDLE (IDLE needs fresh connection)
                await imapService.disconnect()

            } catch {
                if !Task.isCancelled {
                    account.syncStatus = .error
                }
            }

            await MainActor.run {
                self.isBackgroundSyncing = false
                self.backgroundSyncTasks.removeValue(forKey: account.id)

                // Start IDLE monitoring after sync completes (if requested)
                if startIdleAfter && !Task.isCancelled {
                    self.startIdleMonitoring(for: account, modelContext: modelContext)
                }
            }
        }
    }

    /// Sync only new messages (incremental sync) - much faster than full sync
    func syncNewMessages(for account: Account, modelContext: ModelContext) async throws {
        guard account.isActive else { return }

        let imapService = getOrCreateIMAPService(for: account)

        do {
            try await imapService.connect()

            // Only sync inbox for speed
            if let inbox = account.folders.first(where: { $0.specialUse == .inbox }) {
                try await syncNewMessagesOnly(for: inbox, using: imapService, modelContext: modelContext)
            }

            try modelContext.save()

        } catch {
            throw SyncError.syncFailed(error)
        }
    }

    /// Start IDLE monitoring for real-time updates
    func startIdleMonitoring(for account: Account, modelContext: ModelContext) {
        guard account.isActive else { return }

        // Cancel existing idle task
        idleTasks[account.id]?.cancel()

        idleTasks[account.id] = Task {
            do {
                let imapService = getOrCreateIMAPService(for: account)
                try await imapService.connect()

                guard let inbox = account.folders.first(where: { $0.specialUse == .inbox }) else {
                    return
                }

                var shouldContinueIdling = true

                while shouldContinueIdling && !Task.isCancelled {
                    let eventStream = try await imapService.startIdle(mailbox: inbox.path)

                    for await event in eventStream {
                        if Task.isCancelled {
                            shouldContinueIdling = false
                            break
                        }

                        switch event {
                        case .newMessages, .expunge:
                            // Stop IDLE before performing sync
                            await imapService.stopIdle()

                            // Now safe to perform mailbox operations
                            // Need to reconnect since IDLE session may be invalidated
                            await imapService.disconnect()
                            try? await imapService.connect()
                            try? await syncMessages(for: inbox, using: imapService, modelContext: modelContext)
                            try? modelContext.save()

                            // Break out of event loop to restart IDLE
                            break

                        case .flagsChanged:
                            // Could refresh flags here
                            break

                        case .connectionLost:
                            // Stop IDLE and reconnect
                            await imapService.stopIdle()
                            await imapService.disconnect()
                            try? await Task.sleep(for: .seconds(2)) // Brief delay before reconnect
                            try? await imapService.connect()
                            break
                        }
                    }
                }
            } catch {
                // Handle IDLE errors silently, will retry on next manual sync
            }
        }
    }

    /// Stop IDLE monitoring for an account
    func stopIdleMonitoring(for account: Account) async {
        // Stop IDLE on the service first
        if let imapService = imapServices[account.id] {
            await imapService.stopIdle()
        }
        // Then cancel the task
        idleTasks[account.id]?.cancel()
        idleTasks.removeValue(forKey: account.id)
    }

    /// Disconnect all services
    func disconnectAll() async {
        // Cancel all tasks
        for task in activeSyncTasks.values {
            task.cancel()
        }
        activeSyncTasks.removeAll()

        for task in idleTasks.values {
            task.cancel()
        }
        idleTasks.removeAll()

        for task in backgroundSyncTasks.values {
            task.cancel()
        }
        backgroundSyncTasks.removeAll()

        // Disconnect all IMAP services
        for (_, service) in imapServices {
            await service.disconnect()
        }
        imapServices.removeAll()

        syncState = .idle
        isBackgroundSyncing = false
    }

    // MARK: - Flag Operations

    /// Mark emails as read
    func markAsRead(_ emails: [Email], modelContext: ModelContext) async throws {
        guard let firstEmail = emails.first,
              let account = firstEmail.account,
              let folder = firstEmail.folder else { return }

        let imapService = getOrCreateIMAPService(for: account)
        try await imapService.connect()

        let uids = emails.map { $0.uid }
        try await imapService.markAsRead(mailbox: folder.path, uids: uids)

        // Update local state
        for email in emails {
            email.isRead = true
        }
        try modelContext.save()
    }

    /// Mark emails as unread
    func markAsUnread(_ emails: [Email], modelContext: ModelContext) async throws {
        guard let firstEmail = emails.first,
              let account = firstEmail.account,
              let folder = firstEmail.folder else { return }

        let imapService = getOrCreateIMAPService(for: account)
        try await imapService.connect()

        let uids = emails.map { $0.uid }
        try await imapService.markAsUnread(mailbox: folder.path, uids: uids)

        // Update local state
        for email in emails {
            email.isRead = false
        }
        try modelContext.save()
    }

    /// Star/flag emails
    func starEmails(_ emails: [Email], modelContext: ModelContext) async throws {
        guard let firstEmail = emails.first,
              let account = firstEmail.account,
              let folder = firstEmail.folder else { return }

        let imapService = getOrCreateIMAPService(for: account)
        try await imapService.connect()

        let uids = emails.map { $0.uid }
        try await imapService.star(mailbox: folder.path, uids: uids)

        // Update local state
        for email in emails {
            email.isStarred = true
        }
        try modelContext.save()
    }

    /// Unstar/unflag emails
    func unstarEmails(_ emails: [Email], modelContext: ModelContext) async throws {
        guard let firstEmail = emails.first,
              let account = firstEmail.account,
              let folder = firstEmail.folder else { return }

        let imapService = getOrCreateIMAPService(for: account)
        try await imapService.connect()

        let uids = emails.map { $0.uid }
        try await imapService.unstar(mailbox: folder.path, uids: uids)

        // Update local state
        for email in emails {
            email.isStarred = false
        }
        try modelContext.save()
    }

    /// Move emails to a folder
    func moveEmails(_ emails: [Email], to destinationFolder: Folder, modelContext: ModelContext) async throws {
        guard let firstEmail = emails.first,
              let account = firstEmail.account,
              let sourceFolder = firstEmail.folder else { return }

        let imapService = getOrCreateIMAPService(for: account)
        try await imapService.connect()

        let uids = emails.map { $0.uid }
        try await imapService.move(mailbox: sourceFolder.path, uids: uids, to: destinationFolder.path)

        // Update local state
        for email in emails {
            email.folder = destinationFolder
        }

        // Update folder counts
        sourceFolder.totalCount -= emails.count
        sourceFolder.unreadCount -= emails.filter { !$0.isRead }.count
        destinationFolder.totalCount += emails.count
        destinationFolder.unreadCount += emails.filter { !$0.isRead }.count

        try modelContext.save()
    }

    /// Delete emails (move to trash)
    func deleteEmails(_ emails: [Email], modelContext: ModelContext) async throws {
        guard let firstEmail = emails.first,
              let account = firstEmail.account else { return }

        // Find trash folder
        guard let trashFolder = account.folders.first(where: { $0.specialUse == .trash }) else {
            // If no trash folder, permanently delete
            for email in emails {
                modelContext.delete(email)
            }
            try modelContext.save()
            return
        }

        try await moveEmails(emails, to: trashFolder, modelContext: modelContext)
    }

    // MARK: - Content Fetching

    /// Fetch the full body content for an email on-demand
    func fetchEmailBody(for email: Email, modelContext: ModelContext) async throws {
        guard let account = email.account,
              let folder = email.folder else { return }

        // Skip if body already fetched
        if email.textBody != nil || email.htmlBody != nil {
            return
        }

        // Skip if already fetching this email
        guard !fetchingBodyForUIDs.contains(email.uid) else { return }
        fetchingBodyForUIDs.insert(email.uid)

        defer {
            fetchingBodyForUIDs.remove(email.uid)
        }

        let imapService = getOrCreateIMAPService(for: account)
        try await imapService.connect()

        let fetchedMessage = try await imapService.fetchMessage(mailbox: folder.path, uid: email.uid)

        // Update email with body content
        email.textBody = fetchedMessage.textBody
        email.htmlBody = fetchedMessage.htmlBody

        try modelContext.save()
    }

    // MARK: - Private Methods

    private func getOrCreateIMAPService(for account: Account) -> IMAPService {
        if let existing = imapServices[account.id] {
            return existing
        }

        let service = IMAPService(account: account, keychainService: keychainService)
        imapServices[account.id] = service
        return service
    }

    private func syncFolders(for account: Account, using imapService: IMAPService, modelContext: ModelContext) async throws {
        let mailboxes = try await imapService.listMailboxes()

        // Get existing folders
        let existingFolders = account.folders
        let existingPaths = Set(existingFolders.map { $0.path })

        // Add new folders
        for mailbox in mailboxes {
            if !existingPaths.contains(mailbox.path) {
                let folder = Folder(
                    name: mailbox.name,
                    path: mailbox.path,
                    specialUse: mailbox.specialUse,
                    delimiter: mailbox.delimiter
                )
                folder.isSelectable = mailbox.isSelectable
                folder.account = account
                modelContext.insert(folder)
            }
        }

        // Remove deleted folders
        let serverPaths = Set(mailboxes.map { $0.path })
        for folder in existingFolders {
            if !serverPaths.contains(folder.path) {
                modelContext.delete(folder)
            }
        }
    }

    private func syncMessages(for folder: Folder, using imapService: IMAPService, modelContext: ModelContext) async throws {
        // Get folder status
        let status = try await imapService.selectMailbox(folder.path)

        // Update folder metadata
        folder.uidValidity = status.uidValidity
        folder.uidNext = status.uidNext
        folder.totalCount = status.messageCount

        // Fetch message infos
        // For now, fetch last 100 messages for performance
        let startUID = max(1, Int(status.uidNext) - 100)
        let messageInfos = try await imapService.fetchMessageInfos(
            mailbox: folder.path,
            range: startUID...Int(status.uidNext)
        )

        // Get existing UIDs
        let existingUIDs = Set(folder.emails.map { $0.uid })

        var unreadCount = 0

        for info in messageInfos {
            guard let uid = info.uid else { continue }

            if !existingUIDs.contains(uid) {
                // Create new email
                let email = Email(
                    uid: uid,
                    subject: info.subject,
                    fromAddress: info.fromAddress,
                    date: info.date
                )
                email.messageId = info.messageId
                email.toAddresses = info.toAddresses
                email.ccAddresses = info.ccAddresses
                email.isRead = info.flags.isSeen
                email.isStarred = info.flags.isFlagged
                email.isDraft = info.flags.isDraft
                email.isDeleted = info.flags.isDeleted
                email.hasAttachments = info.hasAttachments
                email.snippet = String(info.subject.prefix(150))
                email.account = folder.account
                email.folder = folder

                modelContext.insert(email)
            } else {
                // Update existing email flags
                if let existingEmail = folder.emails.first(where: { $0.uid == uid }) {
                    existingEmail.isRead = info.flags.isSeen
                    existingEmail.isStarred = info.flags.isFlagged
                    existingEmail.isDraft = info.flags.isDraft
                    existingEmail.isDeleted = info.flags.isDeleted
                }
            }

            if !info.flags.isSeen {
                unreadCount += 1
            }
        }

        folder.unreadCount = unreadCount
    }

    /// Sync only new messages since last known UID - faster than full sync
    private func syncNewMessagesOnly(for folder: Folder, using imapService: IMAPService, modelContext: ModelContext) async throws {
        // Get folder status
        let status = try await imapService.selectMailbox(folder.path)

        // Check if UID validity changed - if so, need full resync
        if folder.uidValidity != 0 && folder.uidValidity != status.uidValidity {
            // UID validity changed, need full resync
            try await syncMessages(for: folder, using: imapService, modelContext: modelContext)
            return
        }

        // Update folder metadata
        folder.uidValidity = status.uidValidity
        folder.uidNext = status.uidNext
        folder.totalCount = status.messageCount

        // Find the highest UID we have
        let existingUIDs = folder.emails.map { $0.uid }
        guard let maxExistingUID = existingUIDs.max() else {
            // No existing messages, do a regular sync
            try await syncMessages(for: folder, using: imapService, modelContext: modelContext)
            return
        }

        // Only fetch messages newer than what we have
        let startUID = Int(maxExistingUID) + 1
        guard startUID < Int(status.uidNext) else {
            // No new messages
            return
        }

        let messageInfos = try await imapService.fetchMessageInfos(
            mailbox: folder.path,
            range: startUID...Int(status.uidNext)
        )

        var newUnread = 0
        for info in messageInfos {
            guard let uid = info.uid else { continue }

            let email = Email(
                uid: uid,
                subject: info.subject,
                fromAddress: info.fromAddress,
                date: info.date
            )
            email.messageId = info.messageId
            email.toAddresses = info.toAddresses
            email.ccAddresses = info.ccAddresses
            email.isRead = info.flags.isSeen
            email.isStarred = info.flags.isFlagged
            email.isDraft = info.flags.isDraft
            email.isDeleted = info.flags.isDeleted
            email.hasAttachments = info.hasAttachments
            email.snippet = String(info.subject.prefix(150))
            email.account = folder.account
            email.folder = folder

            modelContext.insert(email)

            if !info.flags.isSeen {
                newUnread += 1
            }
        }

        folder.unreadCount += newUnread
    }
}

// MARK: - Environment Key

private struct SyncServiceKey: EnvironmentKey {
    static let defaultValue: SyncService = SyncService()
}

extension EnvironmentValues {
    var syncService: SyncService {
        get { self[SyncServiceKey.self] }
        set { self[SyncServiceKey.self] = newValue }
    }
}
