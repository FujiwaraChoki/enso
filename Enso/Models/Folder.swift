import Foundation
import SwiftData

enum FolderType: String, Codable {
    case inbox
    case sent
    case drafts
    case trash
    case spam
    case archive
    case all
    case custom
}

@Model
final class Folder {
    @Attribute(.unique) var id: UUID
    var name: String
    var path: String
    var specialUse: FolderType?
    var delimiter: String

    var unreadCount: Int
    var totalCount: Int
    var uidValidity: UInt32?
    var uidNext: UInt32?

    var isSubscribed: Bool
    var isSelectable: Bool

    // Relationships
    var account: Account?

    @Relationship(deleteRule: .cascade, inverse: \Email.folder)
    var emails: [Email] = []

    // Hierarchy
    var parent: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    var children: [Folder] = []

    init(
        name: String,
        path: String,
        specialUse: FolderType? = nil,
        delimiter: String = "/"
    ) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.specialUse = specialUse
        self.delimiter = delimiter
        self.unreadCount = 0
        self.totalCount = 0
        self.isSubscribed = true
        self.isSelectable = true
    }

    var icon: String {
        switch specialUse {
        case .inbox: return "tray.fill"
        case .sent: return "paperplane.fill"
        case .drafts: return "doc.fill"
        case .trash: return "trash.fill"
        case .spam: return "xmark.bin.fill"
        case .archive: return "archivebox.fill"
        case .all: return "tray.2.fill"
        case .custom, .none: return "folder.fill"
        }
    }
}
