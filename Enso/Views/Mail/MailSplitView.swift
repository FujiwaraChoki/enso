//
//  MailSplitView.swift
//  Enso
//

import SwiftUI
import SwiftData
import Shimmer

struct MailSplitView: View {
    let folderId: UUID?
    let onCompose: () -> Void
    let onToggleAI: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService
    @EnvironmentObject private var tabManager: TabManager
    @Query private var accounts: [Account]
    @State private var selectedFolder: Folder?
    @State private var selectedEmail: Email?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var syncError: String?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - Accounts & Folders
            SidebarView(selectedFolder: $selectedFolder)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } content: {
            // Email List - Chronicle view with timeline sections
            ChronicleEmailListView(
                folder: selectedFolder,
                selectedEmail: $selectedEmail,
                isBackgroundSyncing: syncService.isBackgroundSyncing,
                onRefresh: { await refreshCurrentFolder() },
                onCompose: onCompose,
                onToggleAI: onToggleAI
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 380, max: 550)
        } detail: {
            // Email Detail
            if let email = selectedEmail {
                EmailDetailView(
                    email: email,
                    onMarkRead: { await markAsRead(email) },
                    onMarkUnread: { await markAsUnread(email) },
                    onStar: { await starEmail(email) },
                    onUnstar: { await unstarEmail(email) },
                    onMove: { folder in await moveEmail(email, to: folder) },
                    onDelete: { await deleteEmail(email) },
                    onReply: { tabManager.openReply(to: email) },
                    onReplyAll: { tabManager.openReplyAll(to: email) },
                    onForward: { tabManager.openForward(email: email) }
                )
            } else {
                EmptyStateView(
                    title: "No Email Selected",
                    systemImage: "envelope.open",
                    description: "Select an email to read its contents"
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .searchableEmails(folder: selectedFolder, selectedEmail: $selectedEmail)
        .onChange(of: selectedFolder) { _, newFolder in
            // Clear selection when folder changes
            selectedEmail = nil
            // Sync new folder if needed
            if let folder = newFolder {
                Task {
                    await syncFolder(folder)
                }
            }
        }
        .onChange(of: selectedEmail) { _, newEmail in
            // Update TabManager so AI sidebar knows the context
            tabManager.selectedEmail = newEmail
        }
        .task {
            // Initial sync on app launch
            await performInitialSync()
        }
        .alert("Sync Error", isPresented: .constant(syncError != nil)) {
            Button("OK") { syncError = nil }
        } message: {
            if let error = syncError {
                Text(error)
            }
        }
    }

    // MARK: - Sync Operations

    private func performInitialSync() async {
        guard let account = accounts.first(where: { $0.isActive }) else { return }

        // Immediately show cached emails - select inbox if we have folders cached
        if selectedFolder == nil {
            selectedFolder = account.folders.first(where: { $0.specialUse == .inbox })
        }

        // Start background sync - doesn't block UI, shows cached data immediately
        // Will skip if cache is still valid (synced recently)
        // IDLE monitoring starts automatically after sync completes to avoid concurrent IMAP operations
        syncService.syncAccountInBackground(account, modelContext: modelContext, startIdleAfter: true)
    }

    private func syncFolder(_ folder: Folder) async {
        guard let account = folder.account else { return }

        // Background sync - don't block the UI
        syncService.syncAccountInBackground(account, modelContext: modelContext, force: true)
    }

    private func refreshCurrentFolder() async {
        guard let folder = selectedFolder,
              let account = folder.account else { return }

        // Force refresh - bypass cache validity check
        do {
            try await syncService.syncNewMessages(for: account, modelContext: modelContext)
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Email Actions

    private func markAsRead(_ email: Email) async {
        do {
            try await syncService.markAsRead([email], modelContext: modelContext)
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func markAsUnread(_ email: Email) async {
        do {
            try await syncService.markAsUnread([email], modelContext: modelContext)
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func starEmail(_ email: Email) async {
        do {
            try await syncService.starEmails([email], modelContext: modelContext)
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func unstarEmail(_ email: Email) async {
        do {
            try await syncService.unstarEmails([email], modelContext: modelContext)
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func deleteEmail(_ email: Email) async {
        do {
            try await syncService.deleteEmails([email], modelContext: modelContext)
            selectedEmail = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func moveEmail(_ email: Email, to folder: Folder) async {
        do {
            try await syncService.moveEmails([email], to: folder, modelContext: modelContext)
            selectedEmail = nil
        } catch {
            syncError = error.localizedDescription
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selectedFolder: Folder?
    @Query private var accounts: [Account]
    @Environment(\.syncService) private var syncService

    var body: some View {
        List(selection: $selectedFolder) {
            if accounts.isEmpty {
                ContentUnavailableView(
                    "No Accounts",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("Add an email account to get started")
                )
            } else {
                ForEach(accounts) { account in
                    Section {
                        ForEach(sortedFolders(for: account)) { folder in
                            Label {
                                HStack {
                                    Text(folder.name)
                                    Spacer()
                                    if folder.unreadCount > 0 {
                                        Text("\(folder.unreadCount)")
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.blue.opacity(0.2))
                                            .clipShape(Capsule())
                                    }
                                }
                            } icon: {
                                Image(systemName: folder.icon)
                                    .foregroundStyle(folder.specialUse == .inbox ? .blue : .secondary)
                            }
                            .tag(folder)
                        }
                    } header: {
                        HStack {
                            Text(account.name.uppercased())
                            Spacer()
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Mailboxes")
    }

    private func sortedFolders(for account: Account) -> [Folder] {
        // Sort folders: special folders first (inbox, sent, drafts, etc.), then custom folders
        let specialOrder: [FolderType] = [.inbox, .drafts, .sent, .archive, .spam, .trash]
        return account.folders.sorted { folder1, folder2 in
            let index1 = specialOrder.firstIndex(of: folder1.specialUse ?? .custom) ?? specialOrder.count
            let index2 = specialOrder.firstIndex(of: folder2.specialUse ?? .custom) ?? specialOrder.count
            if index1 != index2 {
                return index1 < index2
            }
            return folder1.name < folder2.name
        }
    }

    @ViewBuilder
    private func syncStatusIndicator(for account: Account) -> some View {
        switch account.syncStatus {
        case .syncing:
            ProgressView()
                .scaleEffect(0.6)
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        case .offline:
            Image(systemName: "wifi.slash")
                .foregroundStyle(.secondary)
                .font(.caption)
        case .idle:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}



// MARK: - Email List View

struct EmailListView: View {
    let folder: Folder?
    @Binding var selectedEmail: Email?
    let isBackgroundSyncing: Bool
    let onRefresh: () async -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService
    @EnvironmentObject private var tabManager: TabManager
    @State private var syncError: String?

    var emails: [Email] {
        folder?.emails.sorted { $0.date > $1.date } ?? []
    }

    var availableFolders: [Folder] {
        guard let account = folder?.account else { return [] }
        return account.folders.filter { $0.id != folder?.id }
    }

    var body: some View {
        List(selection: $selectedEmail) {
            // Show cached emails immediately - even while syncing
            if emails.isEmpty && !isBackgroundSyncing {
                ContentUnavailableView(
                    "No Emails",
                    systemImage: "tray",
                    description: Text(folder == nil ? "Select a folder" : "This folder is empty")
                )
            } else if emails.isEmpty && isBackgroundSyncing {
                // Only show loading when we have no cached data AND are syncing
                HStack {
                    Spacer()
                    ProgressView("Loading emails...")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(emails) { email in
                    EmailRowView(
                        email: email,
                        onMarkRead: { await markAsRead(email) },
                        onMarkUnread: { await markAsUnread(email) },
                        onStar: { await starEmail(email) },
                        onUnstar: { await unstarEmail(email) },
                        onDelete: { await deleteEmail(email) },
                        onReply: { tabManager.openReply(to: email) },
                        onReplyAll: { tabManager.openReplyAll(to: email) },
                        onForward: { tabManager.openForward(email: email) },
                        folders: availableFolders,
                        onMove: { folder in await moveEmail(email, to: folder) }
                    )
                    .tag(email)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(folder?.name ?? "Inbox")
        .toolbar {
            ToolbarItem(placement: .status) {
                HStack(spacing: 8) {
                    // Subtle background sync indicator
                    if isBackgroundSyncing && !emails.isEmpty {
                        ProgressView()
                            .scaleEffect(0.6)
                            .help("Syncing in background...")
                    }

                    Button(action: {
                        Task { await onRefresh() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")
                }
            }
        }
        .refreshable {
            await onRefresh()
        }
        .alert("Error", isPresented: .constant(syncError != nil)) {
            Button("OK") { syncError = nil }
        } message: {
            if let error = syncError {
                Text(error)
            }
        }
    }

    // MARK: - Email Actions

    private func markAsRead(_ email: Email) async {
        do {
            try await syncService.markAsRead([email], modelContext: modelContext)
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func markAsUnread(_ email: Email) async {
        do {
            try await syncService.markAsUnread([email], modelContext: modelContext)
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func starEmail(_ email: Email) async {
        do {
            try await syncService.starEmails([email], modelContext: modelContext)
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func unstarEmail(_ email: Email) async {
        do {
            try await syncService.unstarEmails([email], modelContext: modelContext)
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func deleteEmail(_ email: Email) async {
        do {
            try await syncService.deleteEmails([email], modelContext: modelContext)
            if selectedEmail?.id == email.id {
                selectedEmail = nil
            }
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func moveEmail(_ email: Email, to folder: Folder) async {
        do {
            try await syncService.moveEmails([email], to: folder, modelContext: modelContext)
            if selectedEmail?.id == email.id {
                selectedEmail = nil
            }
        } catch {
            syncError = error.localizedDescription
        }
    }
}

// MARK: - Email Row View

struct EmailRowView: View {
    let email: Email
    let onMarkRead: () async -> Void
    let onMarkUnread: () async -> Void
    let onStar: () async -> Void
    let onUnstar: () async -> Void
    let onDelete: () async -> Void
    let onReply: () -> Void
    let onReplyAll: () -> Void
    let onForward: () -> Void
    let folders: [Folder]
    let onMove: (Folder) async -> Void
    @State private var isDeleting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Unread indicator
                Circle()
                    .fill(email.isRead ? .clear : .blue)
                    .frame(width: 8, height: 8)

                // Sender
                Text(email.senderDisplayName)
                    .font(.headline)
                    .fontWeight(email.isRead ? .regular : .semibold)
                    .lineLimit(1)

                Spacer()

                // Date
                Text(email.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Subject
            Text(email.subject)
                .font(.subheadline)
                .fontWeight(email.isRead ? .regular : .medium)
                .lineLimit(1)

            // Preview
            Text(email.previewText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            // Indicators
            HStack(spacing: 8) {
                if email.hasAttachments {
                    Image(systemName: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if email.isStarred {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(email.isRead ? 0.8 : 1.0)
        .shimmering(active: isDeleting)
        .contextMenu {
            // Reply actions
            Button(action: onReply) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            Button(action: onReplyAll) {
                Label("Reply All", systemImage: "arrowshape.turn.up.left.2")
            }
            Button(action: onForward) {
                Label("Forward", systemImage: "arrowshape.turn.up.right")
            }

            Divider()

            // Flag actions
            if email.isRead {
                Button(action: { Task { await onMarkUnread() } }) {
                    Label("Mark as Unread", systemImage: "envelope.badge")
                }
            } else {
                Button(action: { Task { await onMarkRead() } }) {
                    Label("Mark as Read", systemImage: "envelope.open")
                }
            }

            if email.isStarred {
                Button(action: { Task { await onUnstar() } }) {
                    Label("Unstar", systemImage: "star.slash")
                }
            } else {
                Button(action: { Task { await onStar() } }) {
                    Label("Star", systemImage: "star")
                }
            }

            Divider()

            // Move to folder
            if !folders.isEmpty {
                Menu {
                    ForEach(folders) { folder in
                        Button(action: { Task { await onMove(folder) } }) {
                            Label(folder.name, systemImage: folder.icon)
                        }
                    }
                } label: {
                    Label("Move to Folder", systemImage: "folder")
                }
            }

            // Delete
            Button(role: .destructive, action: { Task { await performDelete() } }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func performDelete() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        await onDelete()
    }
}

// MARK: - Email Detail View

struct EmailDetailView: View {
    let email: Email
    let onMarkRead: () async -> Void
    let onMarkUnread: () async -> Void
    let onStar: () async -> Void
    let onUnstar: () async -> Void
    let onMove: (Folder) async -> Void
    let onDelete: () async -> Void
    let onReply: () -> Void
    let onReplyAll: () -> Void
    let onForward: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService
    @State private var isLoadingBody = false
    @State private var webViewHeight: CGFloat = 100
    @State private var fetchTask: Task<Void, Never>?
    @State private var showMoveSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed Header
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    Text(email.subject)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .layoutPriority(1)

                    Spacer(minLength: 12)

                    MailActionBar(
                        email: email,
                        onReply: { _ in onReply() },
                        onReplyAll: { _ in onReplyAll() },
                        onForward: { _ in onForward() },
                        onMarkRead: { _ in await onMarkRead() },
                        onMarkUnread: { _ in await onMarkUnread() },
                        onStar: { _ in await onStar() },
                        onUnstar: { _ in await onUnstar() },
                        onMove: { _ in showMoveSheet = true },
                        onDelete: { _ in await onDelete() }
                    )
                }

                HStack {
                    // Avatar placeholder
                    Circle()
                        .fill(.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Text(String(email.senderDisplayName.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }

                    VStack(alignment: .leading) {
                        Text(email.senderDisplayName)
                            .font(.headline)
                        Text(email.fromAddress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(email.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Recipients
                if !email.toAddresses.isEmpty {
                    HStack {
                        Text("To:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(email.toAddresses.joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
            .padding()

            Divider()

            // Scrollable Body
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Body
                    if let htmlBody = email.htmlBody {
                        EmailWebView(html: htmlBody, dynamicHeight: $webViewHeight)
                            .frame(maxWidth: .infinity, minHeight: webViewHeight, alignment: .topLeading)
                    } else if let textBody = email.textBody {
                        Text(textBody)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                    } else if isLoadingBody {
                        VStack {
                            ProgressView()
                                .controlSize(.large)
                            Text("Loading email content...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        Text("No content")
                            .foregroundStyle(.secondary)
                            .padding()
                    }

                    // Attachments
                    if !email.attachments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Attachments")
                                .font(.headline)

                            ForEach(email.attachments) { attachment in
                                HStack {
                                    Image(systemName: attachment.icon)
                                        .foregroundStyle(.blue)
                                    VStack(alignment: .leading) {
                                        Text(attachment.filename)
                                            .font(.subheadline)
                                        Text(attachment.formattedSize)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Download") {
                                        // TODO: Implement download
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(8)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.background)
                                }
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveFolderSheet(email: email, onMove: { folder in
                await onMove(folder)
            })
        }
        .onChange(of: email.id) { _, _ in
            // Cancel any pending fetch when email changes
            fetchTask?.cancel()
            fetchTask = nil
            webViewHeight = 100
            isLoadingBody = false
        }
        .task(id: email.id) {
            // Mark as read when viewed
            if !email.isRead {
                await onMarkRead()
            }

            // Fetch body content if not already loaded
            if email.textBody == nil && email.htmlBody == nil {
                isLoadingBody = true

                // Small delay to avoid rapid successive fetches
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else {
                    isLoadingBody = false
                    return
                }

                do {
                    try await syncService.fetchEmailBody(for: email, modelContext: modelContext)
                } catch {
                    if !Task.isCancelled {
                        print("Failed to fetch email body: \(error)")
                    }
                }
                isLoadingBody = false
            }
        }
    }
}

#Preview {
    MailSplitView(
        folderId: nil,
        onCompose: {},
        onToggleAI: {}
    )
        .modelContainer(for: [Account.self, Email.self, Folder.self])
}
