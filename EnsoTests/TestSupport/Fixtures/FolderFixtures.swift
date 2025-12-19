//
//  FolderFixtures.swift
//  EnsoTests
//

import Foundation
@testable import Enso

/// Factory for creating Folder test fixtures
enum FolderFixtures {

    // MARK: - Basic Factory

    /// Create a test folder with customizable properties
    static func createFolder(
        name: String = "Test Folder",
        path: String = "TestFolder",
        specialUse: FolderType? = nil,
        delimiter: String = "/",
        unreadCount: Int = 0,
        totalCount: Int = 0,
        uidValidity: UInt32? = nil,
        uidNext: UInt32? = nil,
        isSubscribed: Bool = true,
        isSelectable: Bool = true
    ) -> Folder {
        let folder = Folder(
            name: name,
            path: path,
            specialUse: specialUse,
            delimiter: delimiter
        )
        folder.unreadCount = unreadCount
        folder.totalCount = totalCount
        folder.uidValidity = uidValidity
        folder.uidNext = uidNext
        folder.isSubscribed = isSubscribed
        folder.isSelectable = isSelectable
        return folder
    }

    // MARK: - Special Use Folders

    /// Create an Inbox folder
    static func createInbox(
        unreadCount: Int = 5,
        totalCount: Int = 100
    ) -> Folder {
        createFolder(
            name: "Inbox",
            path: "INBOX",
            specialUse: .inbox,
            unreadCount: unreadCount,
            totalCount: totalCount
        )
    }

    /// Create a Sent folder
    static func createSentFolder(totalCount: Int = 50) -> Folder {
        createFolder(
            name: "Sent",
            path: "Sent",
            specialUse: .sent,
            totalCount: totalCount
        )
    }

    /// Create a Drafts folder
    static func createDraftsFolder(totalCount: Int = 3) -> Folder {
        createFolder(
            name: "Drafts",
            path: "Drafts",
            specialUse: .drafts,
            totalCount: totalCount
        )
    }

    /// Create a Trash folder
    static func createTrashFolder(totalCount: Int = 10) -> Folder {
        createFolder(
            name: "Trash",
            path: "Trash",
            specialUse: .trash,
            totalCount: totalCount
        )
    }

    /// Create a Spam folder
    static func createSpamFolder(
        unreadCount: Int = 2,
        totalCount: Int = 15
    ) -> Folder {
        createFolder(
            name: "Spam",
            path: "Spam",
            specialUse: .spam,
            unreadCount: unreadCount,
            totalCount: totalCount
        )
    }

    /// Create an Archive folder
    static func createArchiveFolder(totalCount: Int = 500) -> Folder {
        createFolder(
            name: "Archive",
            path: "Archive",
            specialUse: .archive,
            totalCount: totalCount
        )
    }

    /// Create an All Mail folder
    static func createAllMailFolder(totalCount: Int = 1000) -> Folder {
        createFolder(
            name: "All Mail",
            path: "[Gmail]/All Mail",
            specialUse: .all,
            totalCount: totalCount
        )
    }

    /// Create a custom folder
    static func createCustomFolder(
        name: String = "Custom",
        path: String? = nil,
        unreadCount: Int = 0,
        totalCount: Int = 0
    ) -> Folder {
        createFolder(
            name: name,
            path: path ?? name,
            specialUse: .custom,
            unreadCount: unreadCount,
            totalCount: totalCount
        )
    }

    // MARK: - Standard Folder Sets

    /// Create a standard set of folders (Inbox, Sent, Drafts, Trash)
    static func createStandardFolderSet() -> [Folder] {
        [
            createInbox(),
            createSentFolder(),
            createDraftsFolder(),
            createTrashFolder()
        ]
    }

    /// Create a Gmail-style folder set
    static func createGmailFolderSet() -> [Folder] {
        [
            createInbox(),
            createSentFolder(),
            createDraftsFolder(),
            createSpamFolder(),
            createTrashFolder(),
            createAllMailFolder(),
            createCustomFolder(name: "Important", path: "[Gmail]/Important"),
            createCustomFolder(name: "Starred", path: "[Gmail]/Starred")
        ]
    }

    // MARK: - Folder Hierarchy

    /// Create a folder with children (nested folders)
    static func createFolderHierarchy() -> Folder {
        let parent = createCustomFolder(name: "Projects", path: "Projects")

        let child1 = createCustomFolder(name: "Work", path: "Projects/Work")
        child1.parent = parent

        let child2 = createCustomFolder(name: "Personal", path: "Projects/Personal")
        child2.parent = parent

        let grandchild = createCustomFolder(name: "Active", path: "Projects/Work/Active")
        grandchild.parent = child1

        parent.children = [child1, child2]
        child1.children = [grandchild]

        return parent
    }

    // MARK: - State Variations

    /// Create a folder with many unread messages
    static func createFolderWithUnread(
        name: String = "Busy Inbox",
        unreadCount: Int = 50,
        totalCount: Int = 200
    ) -> Folder {
        createFolder(
            name: name,
            path: name,
            specialUse: .inbox,
            unreadCount: unreadCount,
            totalCount: totalCount
        )
    }

    /// Create an empty folder
    static func createEmptyFolder(name: String = "Empty") -> Folder {
        createFolder(
            name: name,
            path: name,
            specialUse: .custom,
            unreadCount: 0,
            totalCount: 0
        )
    }

    /// Create a non-selectable folder (container only)
    static func createContainerFolder(name: String = "Container") -> Folder {
        createFolder(
            name: name,
            path: name,
            isSelectable: false
        )
    }

    /// Create an unsubscribed folder
    static func createUnsubscribedFolder(name: String = "Unsubscribed") -> Folder {
        createFolder(
            name: name,
            path: name,
            isSubscribed: false
        )
    }

    // MARK: - Batch Creation

    /// Create multiple custom folders
    static func createMultipleFolders(count: Int = 5) -> [Folder] {
        (1...count).map { index in
            createCustomFolder(
                name: "Folder \(index)",
                path: "Folder\(index)"
            )
        }
    }
}
