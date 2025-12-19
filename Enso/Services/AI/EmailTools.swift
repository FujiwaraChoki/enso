//
//  EmailTools.swift
//  Enso
//

import Foundation
import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Search Emails Tool

/// Tool for searching emails via AI
@Generable
struct SearchEmailsInput: Sendable {
    @Guide(description: "The search query to find emails")
    var query: String

    @Guide(description: "Filter by sender email address")
    var fromAddress: String?

    @Guide(description: "Filter to only show unread emails")
    var unreadOnly: Bool?

    @Guide(description: "Filter to only show starred emails")
    var starredOnly: Bool?

    @Guide(description: "Number of days to search back (e.g., 7 for last week)")
    var daysBack: Int?
}

struct SearchEmailsTool: @unchecked Sendable {
    let modelContext: ModelContext

    var name: String { "search_emails" }

    var description: String {
        "Search through emails by query, sender, date range, or status"
    }

    func call(arguments: SearchEmailsInput) async throws -> String {
        var descriptor = FetchDescriptor<Email>()
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        descriptor.fetchLimit = 20

        let emails = try modelContext.fetch(descriptor)

        let filtered = emails.filter { email in
            var matches = true

            if !arguments.query.isEmpty {
                matches = matches && (
                    email.subject.localizedCaseInsensitiveContains(arguments.query) ||
                    email.fromAddress.localizedCaseInsensitiveContains(arguments.query) ||
                    (email.textBody?.localizedCaseInsensitiveContains(arguments.query) ?? false)
                )
            }

            if let from = arguments.fromAddress, !from.isEmpty {
                matches = matches && email.fromAddress.localizedCaseInsensitiveContains(from)
            }

            if let daysBack = arguments.daysBack, daysBack > 0 {
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
                matches = matches && email.date >= cutoffDate
            }

            if arguments.unreadOnly == true {
                matches = matches && !email.isRead
            }

            if arguments.starredOnly == true {
                matches = matches && email.isStarred
            }

            return matches
        }

        if filtered.isEmpty {
            return "No emails found matching your criteria."
        }

        var result = "Found \(filtered.count) email(s):\n\n"
        for email in filtered.prefix(5) {
            result += "- From: \(email.senderDisplayName)\n"
            result += "  Subject: \(email.subject)\n"
            result += "  Date: \(email.date.formatted())\n"
            result += "  \(email.isRead ? "Read" : "Unread")\(email.isStarred ? ", Starred" : "")\n\n"
        }

        return result
    }
}

@MainActor
extension SearchEmailsTool: Tool {}

// MARK: - Compose Email Tool

@Generable
struct ComposeEmailInput: Sendable {
    @Guide(description: "Recipient email address(es), comma-separated")
    var to: String

    @Guide(description: "Email subject line")
    var subject: String

    @Guide(description: "Email body content")
    var body: String

    @Guide(description: "CC recipients, comma-separated")
    var cc: String?
}

struct ComposeEmailTool: @unchecked Sendable {
    let draftService: DraftService
    let accountId: UUID

    var name: String { "compose_email" }

    var description: String {
        "Create a new email draft with specified recipients, subject, and body"
    }

    func call(arguments: ComposeEmailInput) async throws -> String {
        let toAddresses = arguments.to.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        let ccAddresses = arguments.cc?.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) } ?? []

        var draft = draftService.createDraft(accountId: accountId)
        draft.toAddresses = toAddresses
        draft.ccAddresses = ccAddresses
        draft.subject = arguments.subject
        draft.textBody = arguments.body
        draftService.updateDraft(draft)

        return "Draft created with subject '\(arguments.subject)' to \(toAddresses.joined(separator: ", ")). The draft is ready for review and sending."
    }
}

@MainActor
extension ComposeEmailTool: Tool {}

// MARK: - Summarize Thread Tool

@Generable
struct SummarizeThreadInput: Sendable {
    @Guide(description: "The thread ID or message ID to summarize")
    var threadId: String
}

struct SummarizeThreadTool: @unchecked Sendable {
    let modelContext: ModelContext

    var name: String { "summarize_thread" }

    var description: String {
        "Summarize an email thread or conversation"
    }

    func call(arguments: SummarizeThreadInput) async throws -> String {
        // Find emails in the thread
        var descriptor = FetchDescriptor<Email>()
        descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]

        let allEmails = try modelContext.fetch(descriptor)
        let threadEmails = allEmails.filter { $0.threadId == arguments.threadId }

        guard !threadEmails.isEmpty else {
            return "No emails found in this thread."
        }

        var summary = "Thread with \(threadEmails.count) email(s):\n\n"
        summary += "Subject: \(threadEmails.first?.subject ?? "Unknown")\n"
        summary += "Participants: \(Set(threadEmails.map { $0.fromAddress }).joined(separator: ", "))\n\n"

        summary += "Timeline:\n"
        for email in threadEmails {
            summary += "- \(email.date.formatted(date: .abbreviated, time: .shortened)): "
            summary += "\(email.senderDisplayName) - \(email.previewText.prefix(50))...\n"
        }

        return summary
    }
}

@MainActor
extension SummarizeThreadTool: Tool {}

// MARK: - Get Email Details Tool

@Generable
struct GetEmailDetailsInput: Sendable {
    @Guide(description: "The email subject or sender to find")
    var identifier: String
}

struct GetEmailDetailsTool: @unchecked Sendable {
    let modelContext: ModelContext

    var name: String { "get_email_details" }

    var description: String {
        "Get full details of a specific email by subject or sender"
    }

    func call(arguments: GetEmailDetailsInput) async throws -> String {
        var descriptor = FetchDescriptor<Email>()
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]

        let emails = try modelContext.fetch(descriptor)
        let email = emails.first { email in
            email.subject.localizedCaseInsensitiveContains(arguments.identifier) ||
            email.fromAddress.localizedCaseInsensitiveContains(arguments.identifier) ||
            (email.fromName?.localizedCaseInsensitiveContains(arguments.identifier) ?? false)
        }

        guard let email = email else {
            return "No email found matching '\(arguments.identifier)'"
        }

        var details = """
        Email Details:
        From: \(email.senderDisplayName) <\(email.fromAddress)>
        To: \(email.toAddresses.joined(separator: ", "))
        Subject: \(email.subject)
        Date: \(email.date.formatted())
        Status: \(email.isRead ? "Read" : "Unread")\(email.isStarred ? ", Starred" : "")
        """

        if email.hasAttachments {
            details += "\nAttachments: Yes (\(email.attachments.count) file(s))"
        }

        details += "\n\nBody:\n\(email.textBody ?? "No content")"

        return details
    }
}

@MainActor
extension GetEmailDetailsTool: Tool {}

// MARK: - Mark Email Tool

@Generable
struct MarkEmailInput: Sendable {
    @Guide(description: "The email subject or sender to identify the email")
    var identifier: String

    @Guide(description: "Action to perform: 'read', 'unread', 'star', 'unstar'")
    var action: String
}

struct MarkEmailTool: @unchecked Sendable {
    let modelContext: ModelContext
    let syncService: SyncService

    var name: String { "mark_email" }

    var description: String {
        "Mark an email as read, unread, starred, or unstarred"
    }

    func call(arguments: MarkEmailInput) async throws -> String {
        var descriptor = FetchDescriptor<Email>()
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]

        let emails = try modelContext.fetch(descriptor)
        guard let email = emails.first(where: { email in
            email.subject.localizedCaseInsensitiveContains(arguments.identifier) ||
            email.fromAddress.localizedCaseInsensitiveContains(arguments.identifier)
        }) else {
            return "No email found matching '\(arguments.identifier)'"
        }

        switch arguments.action.lowercased() {
        case "read":
            try await syncService.markAsRead([email], modelContext: modelContext)
            return "Marked email '\(email.subject)' as read."

        case "unread":
            try await syncService.markAsUnread([email], modelContext: modelContext)
            return "Marked email '\(email.subject)' as unread."

        case "star":
            try await syncService.starEmails([email], modelContext: modelContext)
            return "Starred email '\(email.subject)'."

        case "unstar":
            try await syncService.unstarEmails([email], modelContext: modelContext)
            return "Unstarred email '\(email.subject)'."

        default:
            return "Unknown action '\(arguments.action)'. Use: read, unread, star, or unstar."
        }
    }
}

@MainActor
extension MarkEmailTool: Tool {}

// MARK: - Folder Stats Tool

@Generable
struct FolderStatsInput: Sendable {
    @Guide(description: "Folder name to get statistics for, or 'all' for all folders")
    var folderName: String
}

struct FolderStatsTool: @unchecked Sendable {
    let modelContext: ModelContext

    var name: String { "folder_stats" }

    var description: String {
        "Get statistics about email folders including count and unread"
    }

    func call(arguments: FolderStatsInput) async throws -> String {
        let descriptor = FetchDescriptor<Folder>()

        let folders = try modelContext.fetch(descriptor)

        if arguments.folderName.lowercased() == "all" {
            var result = "Email folder statistics:\n\n"
            for folder in folders {
                result += "- \(folder.name): \(folder.totalCount) total, \(folder.unreadCount) unread\n"
            }
            return result
        } else {
            guard let folder = folders.first(where: { $0.name.localizedCaseInsensitiveContains(arguments.folderName) }) else {
                return "Folder '\(arguments.folderName)' not found."
            }

            return """
            Folder: \(folder.name)
            Total emails: \(folder.totalCount)
            Unread: \(folder.unreadCount)
            """
        }
    }
}

@MainActor
extension FolderStatsTool: Tool {}
