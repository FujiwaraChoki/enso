//
//  ChronicleEmailListView.swift
//  Enso
//
//  Editorial Chronicle - A distinctive email list presentation
//  that treats your inbox like a curated publication with
//  timeline-based sections and typographic hierarchy.
//

import SwiftUI
import SwiftData
import Shimmer

// MARK: - Chronicle Email List View

struct ChronicleEmailListView: View {
    let folder: Folder?
    @Binding var selectedEmail: Email?
    let isBackgroundSyncing: Bool
    let onRefresh: () async -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService
    @EnvironmentObject private var tabManager: TabManager
    @State private var syncError: String?

    private var emails: [Email] {
        folder?.emails.sorted { $0.date > $1.date } ?? []
    }

    private var availableFolders: [Folder] {
        guard let account = folder?.account else { return [] }
        return account.folders.filter { $0.id != folder?.id }
    }

    /// Groups emails by time period for the chronicle layout
    private var groupedEmails: [(section: TimeSection, emails: [Email])] {
        let calendar = Calendar.current
        let now = Date()

        var groups: [TimeSection: [Email]] = [:]

        for email in emails {
            let section = TimeSection.from(date: email.date, relativeTo: now, calendar: calendar)
            groups[section, default: []].append(email)
        }

        return TimeSection.allCases
            .compactMap { section in
                guard let sectionEmails = groups[section], !sectionEmails.isEmpty else { return nil }
                return (section: section, emails: sectionEmails)
            }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if emails.isEmpty && !isBackgroundSyncing {
                    emptyStateView
                } else if emails.isEmpty && isBackgroundSyncing {
                    loadingView
                } else {
                    chronicleContent
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        }
        .navigationTitle(folder?.name ?? "Inbox")
        .toolbar { toolbarContent }
        .refreshable { await onRefresh() }
        .alert("Error", isPresented: .constant(syncError != nil)) {
            Button("OK") { syncError = nil }
        } message: {
            if let error = syncError {
                Text(error)
            }
        }
    }

    // MARK: - Chronicle Content

    @ViewBuilder
    private var chronicleContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(groupedEmails, id: \.section) { group in
                ChronicleSectionHeader(section: group.section, emailCount: group.emails.count)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                ForEach(group.emails) { email in
                    ChronicleEmailRow(
                        email: email,
                        isSelected: selectedEmail?.id == email.id,
                        isFirstInSection: email.id == group.emails.first?.id,
                        isLastInSection: email.id == group.emails.last?.id,
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedEmail = email
                    }
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Empty & Loading States

    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Emails",
            systemImage: "tray",
            description: Text(folder == nil ? "Select a folder" : "This folder is empty")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var loadingView: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading emails...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .status) {
            if isBackgroundSyncing && !emails.isEmpty {
                ProgressView()
                    .scaleEffect(0.6)
                    .help("Syncing in background...")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: { Task { await onRefresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.glass)
            .help("Refresh")
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

// MARK: - Time Section

enum TimeSection: Int, CaseIterable, Comparable {
    case now = 0        // Within last hour
    case today = 1
    case yesterday = 2
    case thisWeek = 3
    case lastWeek = 4
    case thisMonth = 5
    case older = 6

    static func < (lhs: TimeSection, rhs: TimeSection) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(date: Date, relativeTo now: Date, calendar: Calendar) -> TimeSection {
        let hourAgo = calendar.date(byAdding: .hour, value: -1, to: now)!
        if date > hourAgo { return .now }

        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInYesterday(date) { return .yesterday }

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        if date > weekAgo { return .thisWeek }

        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!
        if date > twoWeeksAgo { return .lastWeek }

        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
        if date > monthAgo { return .thisMonth }

        return .older
    }

    var title: String {
        switch self {
        case .now: return "Just Now"
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .lastWeek: return "Last Week"
        case .thisMonth: return "This Month"
        case .older: return "Earlier"
        }
    }

    var subtitle: String? {
        switch self {
        case .now: return "Recent arrivals"
        case .today:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: Date())
        case .yesterday:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        default: return nil
        }
    }
}

// MARK: - Chronicle Section Header

struct ChronicleSectionHeader: View {
    let section: TimeSection
    let emailCount: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // Timeline marker
            VStack(spacing: 0) {
                Circle()
                    .fill(section == .now ? Color.accentColor : Color.secondary.opacity(0.4))
                    .frame(width: section == .now ? 10 : 8, height: section == .now ? 10 : 8)
            }
            .frame(width: 44)

            // Section title
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.instrumentSerif(size: section == .now ? 20 : 17))
                    .foregroundStyle(section == .now ? .primary : .secondary)

                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Email count badge
            Text("\(emailCount)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
        .padding(.vertical, 12)
        .padding(.trailing, 4)
    }
}

// MARK: - Chronicle Email Row

struct ChronicleEmailRow: View {
    let email: Email
    let isSelected: Bool
    let isFirstInSection: Bool
    let isLastInSection: Bool
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

    @State private var isHovered = false
    @State private var isDeleting = false

    /// Generate a consistent color from sender name/email
    private var senderColor: Color {
        let hash = abs(email.fromAddress.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.75)
    }

    /// Get first letter from sender name or email
    private var senderInitial: String {
        let name = email.senderDisplayName
        if !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        // Fallback to first letter of email address
        return String(email.fromAddress.prefix(1)).uppercased()
    }

    /// Get sender name for display
    private var displaySenderName: String {
        email.fromName ?? email.fromAddress.components(separatedBy: "@").first ?? email.fromAddress
    }

    /// Get sender email for display
    private var displaySenderEmail: String {
        email.fromAddress
    }

    /// Time display based on recency
    private var timeDisplay: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(email.date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: email.date)
        } else if calendar.isDateInYesterday(email.date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: email.date)
        } else {
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
            if email.date > weekAgo {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                return formatter.string(from: email.date)
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: email.date)
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Timeline spine
            timelineSpine

            // Main content card
            HStack(alignment: .top, spacing: 12) {
                // Sender monogram
                senderMonogram

                // Email content
                VStack(alignment: .leading, spacing: email.isRead ? 3 : 5) {
                    // Header row: Sender + Time
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displaySenderName)
                                .font(email.isRead ? .subheadline : .headline)
                                .fontWeight(email.isRead ? .regular : .semibold)
                                .foregroundStyle(isSelected ? .white : .primary)
                                .lineLimit(1)

                            Text(displaySenderEmail)
                                .font(.caption)
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Indicators
                        HStack(spacing: 6) {
                            if email.isStarred {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .yellow)
                            }

                            if email.hasAttachments {
                                Image(systemName: "paperclip")
                                    .font(.caption2)
                                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                            }

                            Text(timeDisplay)
                                .font(.caption)
                                .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                        }
                    }

                    // Subject line with action buttons
                    HStack(spacing: 8) {
                        Text(email.subject)
                            .font(email.isRead ? .caption : .subheadline)
                            .fontWeight(email.isRead ? .regular : .medium)
                            .foregroundStyle(isSelected ? .white.opacity(0.9) : (email.isRead ? .secondary : .primary))
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        // Action buttons
                        HStack(spacing: 6) {
                            Button(action: onReply) {
                                Image(systemName: "arrowshape.turn.up.left")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .help("Reply")

                            Button(action: onReplyAll) {
                                Image(systemName: "arrowshape.turn.up.left.2")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .help("Reply All")

                            Button(action: onForward) {
                                Image(systemName: "arrowshape.turn.up.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .help("Forward")

                            Rectangle()
                                .fill(isSelected ? .white.opacity(0.3) : .secondary.opacity(0.3))
                                .frame(width: 1, height: 12)

                            Button(action: { Task { await email.isRead ? onMarkUnread() : onMarkRead() } }) {
                                Image(systemName: email.isRead ? "envelope.badge" : "envelope.open")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .help(email.isRead ? "Mark as Unread" : "Mark as Read")

                            Button(action: { Task { await email.isStarred ? onUnstar() : onStar() } }) {
                                Image(systemName: email.isStarred ? "star.fill" : "star")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(isSelected ? .white.opacity(0.8) : (email.isStarred ? .yellow : .secondary))
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .help(email.isStarred ? "Unstar" : "Star")

                            if !folders.isEmpty {
                                Menu {
                                    ForEach(folders) { folder in
                                        Button(action: { Task { await onMove(folder) } }) {
                                            Label(folder.name, systemImage: folder.icon)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "folder")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(.plain)
                                .help("Move to Folder")
                            }

                            Button(action: { Task { await performDelete() } }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            .help("Delete")
                        }
                        .opacity(isSelected || isHovered ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.15), value: isSelected || isHovered)
                    }

                    // Preview - always show for unread
                    if !email.isRead {
                        Text(email.previewText)
                            .font(.caption)
                            .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color.secondary.opacity(0.7))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, email.isRead ? 8 : 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : .clear)
            )
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
            .shimmering(active: isDeleting)
        }
        .opacity(email.isRead && !isSelected ? 0.85 : 1.0)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu { contextMenuContent }
    }

    // MARK: - Timeline Spine

    @ViewBuilder
    private var timelineSpine: some View {
        VStack(spacing: 0) {
            // Top connector
            Rectangle()
                .fill(isFirstInSection ? .clear : Color.secondary.opacity(0.2))
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            // Node
            Circle()
                .fill(email.isRead ? Color.secondary.opacity(0.3) : Color.accentColor)
                .frame(width: email.isRead ? 6 : 8, height: email.isRead ? 6 : 8)

            // Bottom connector
            Rectangle()
                .fill(isLastInSection ? .clear : Color.secondary.opacity(0.2))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 44)
    }

    // MARK: - Sender Monogram

    @ViewBuilder
    private var senderMonogram: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.white.opacity(0.2) : senderColor.opacity(email.isRead ? 0.15 : 0.25))

            Text(senderInitial)
                .font(.system(size: email.isRead ? 13 : 15, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : senderColor)
        }
        .frame(width: email.isRead ? 32 : 38, height: email.isRead ? 32 : 38)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
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

        Button(role: .destructive, action: { Task { await performDelete() } }) {
            Label("Delete", systemImage: "trash")
        }
    }

    private func performDelete() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        await onDelete()
    }
}

// MARK: - Preview

#Preview("Chronicle Email List") {
    ChronicleEmailListView(
        folder: nil,
        selectedEmail: .constant(nil),
        isBackgroundSyncing: false,
        onRefresh: {}
    )
    .frame(width: 400, height: 600)
}
