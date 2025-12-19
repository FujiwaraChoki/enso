import Foundation
import SwiftData

@Model
final class Email {
    @Attribute(.unique) var id: UUID
    var uid: UInt32
    var messageId: String?

    // Headers
    var subject: String
    var fromAddress: String
    var fromName: String?
    var toAddresses: [String]
    var ccAddresses: [String]
    var bccAddresses: [String]
    var replyToAddress: String?

    // Content
    var textBody: String?
    var htmlBody: String?
    var snippet: String?

    // Dates
    var date: Date
    var receivedDate: Date

    // Flags
    var isRead: Bool
    var isStarred: Bool
    var isDraft: Bool
    var isDeleted: Bool
    var hasAttachments: Bool

    // Thread support
    var threadId: String?
    var inReplyTo: String?
    var references: [String]

    // Relationships
    var account: Account?
    var folder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Attachment.email)
    var attachments: [Attachment] = []

    // Computed property for search (not indexed directly)
    var searchableContent: String {
        [subject, fromName ?? "", fromAddress, textBody ?? ""]
            .joined(separator: " ")
    }

    init(
        uid: UInt32,
        subject: String,
        fromAddress: String,
        fromName: String? = nil,
        date: Date
    ) {
        self.id = UUID()
        self.uid = uid
        self.subject = subject
        self.fromAddress = fromAddress
        self.fromName = fromName
        self.date = date
        self.receivedDate = Date()
        self.toAddresses = []
        self.ccAddresses = []
        self.bccAddresses = []
        self.isRead = false
        self.isStarred = false
        self.isDraft = false
        self.isDeleted = false
        self.hasAttachments = false
        self.references = []
    }

    var senderDisplayName: String {
        fromName ?? fromAddress
    }

    var previewText: String {
        snippet ?? textBody?.prefix(150).description ?? ""
    }

    /// Returns the best available plain text content for AI processing
    /// Prefers textBody, falls back to stripped HTML
    var plainTextContent: String? {
        if let text = textBody, !text.isEmpty {
            return text
        }
        if let html = htmlBody, !html.isEmpty {
            let stripped = html.strippingHTML
            return stripped.isEmpty ? nil : stripped
        }
        return nil
    }
}
