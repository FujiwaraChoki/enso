//
//  FolderTests.swift
//  EnsoTests
//

import XCTest
import SwiftData
@testable import Enso

final class FolderTests: XCTestCase {

    // MARK: - icon Tests

    func test_icon_returnsCorrectIcon_forInbox() {
        let folder = FolderFixtures.createInbox()

        XCTAssertEqual(folder.icon, "tray.fill")
    }

    func test_icon_returnsCorrectIcon_forSent() {
        let folder = FolderFixtures.createSentFolder()

        XCTAssertEqual(folder.icon, "paperplane.fill")
    }

    func test_icon_returnsCorrectIcon_forDrafts() {
        let folder = FolderFixtures.createDraftsFolder()

        XCTAssertEqual(folder.icon, "doc.fill")
    }

    func test_icon_returnsCorrectIcon_forTrash() {
        let folder = FolderFixtures.createTrashFolder()

        XCTAssertEqual(folder.icon, "trash.fill")
    }

    func test_icon_returnsCorrectIcon_forSpam() {
        let folder = FolderFixtures.createSpamFolder()

        XCTAssertEqual(folder.icon, "xmark.bin.fill")
    }

    func test_icon_returnsCorrectIcon_forArchive() {
        let folder = FolderFixtures.createArchiveFolder()

        XCTAssertEqual(folder.icon, "archivebox.fill")
    }

    func test_icon_returnsCorrectIcon_forAll() {
        let folder = FolderFixtures.createAllMailFolder()

        XCTAssertEqual(folder.icon, "tray.2.fill")
    }

    func test_icon_returnsCorrectIcon_forCustom() {
        let folder = FolderFixtures.createCustomFolder()

        XCTAssertEqual(folder.icon, "folder.fill")
    }

    func test_icon_returnsCorrectIcon_forNilSpecialUse() {
        let folder = FolderFixtures.createFolder(specialUse: nil)

        XCTAssertEqual(folder.icon, "folder.fill")
    }

    // MARK: - Initialization Tests

    func test_init_setsDefaultValues() {
        let folder = Folder(name: "Test", path: "Test")

        XCTAssertEqual(folder.delimiter, "/")
        XCTAssertEqual(folder.unreadCount, 0)
        XCTAssertEqual(folder.totalCount, 0)
        XCTAssertNil(folder.uidValidity)
        XCTAssertNil(folder.uidNext)
        XCTAssertTrue(folder.isSubscribed)
        XCTAssertTrue(folder.isSelectable)
        XCTAssertNil(folder.specialUse)
    }

    func test_init_setsProvidedValues() {
        let folder = Folder(
            name: "Custom",
            path: "Custom/Path",
            specialUse: .inbox,
            delimiter: "."
        )

        XCTAssertEqual(folder.name, "Custom")
        XCTAssertEqual(folder.path, "Custom/Path")
        XCTAssertEqual(folder.specialUse, .inbox)
        XCTAssertEqual(folder.delimiter, ".")
    }

    // MARK: - Count Tests

    func test_unreadCount_canBeModified() {
        let folder = FolderFixtures.createFolder()

        folder.unreadCount = 10

        XCTAssertEqual(folder.unreadCount, 10)
    }

    func test_totalCount_canBeModified() {
        let folder = FolderFixtures.createFolder()

        folder.totalCount = 100

        XCTAssertEqual(folder.totalCount, 100)
    }

    // MARK: - UID Tests

    func test_uidValidity_canBeSet() {
        let folder = FolderFixtures.createFolder()

        folder.uidValidity = 12345

        XCTAssertEqual(folder.uidValidity, 12345)
    }

    func test_uidNext_canBeSet() {
        let folder = FolderFixtures.createFolder()

        folder.uidNext = 101

        XCTAssertEqual(folder.uidNext, 101)
    }

    // MARK: - Subscription Tests

    func test_isSubscribed_canBeModified() {
        let folder = FolderFixtures.createFolder()

        folder.isSubscribed = false

        XCTAssertFalse(folder.isSubscribed)
    }

    func test_isSelectable_canBeModified() {
        let folder = FolderFixtures.createFolder()

        folder.isSelectable = false

        XCTAssertFalse(folder.isSelectable)
    }

    // MARK: - Relationship Tests

    func test_account_startsNil() {
        let folder = FolderFixtures.createFolder()

        XCTAssertNil(folder.account)
    }

    func test_emails_startsEmpty() {
        let folder = FolderFixtures.createFolder()

        XCTAssertTrue(folder.emails.isEmpty)
    }

    func test_parent_startsNil() {
        let folder = FolderFixtures.createFolder()

        XCTAssertNil(folder.parent)
    }

    func test_children_startsEmpty() {
        let folder = FolderFixtures.createFolder()

        XCTAssertTrue(folder.children.isEmpty)
    }

    // MARK: - Fixture Tests

    func test_standardFolderSet_containsBasicFolders() {
        let folders = FolderFixtures.createStandardFolderSet()

        XCTAssertEqual(folders.count, 4)

        let specialUses = folders.compactMap { $0.specialUse }
        XCTAssertTrue(specialUses.contains(.inbox))
        XCTAssertTrue(specialUses.contains(.sent))
        XCTAssertTrue(specialUses.contains(.drafts))
        XCTAssertTrue(specialUses.contains(.trash))
    }

    func test_gmailFolderSet_containsGmailFolders() {
        let folders = FolderFixtures.createGmailFolderSet()

        XCTAssertEqual(folders.count, 8)

        // Should have All Mail folder
        let allMail = folders.first { $0.specialUse == .all }
        XCTAssertNotNil(allMail)
    }

    func test_folderHierarchy_hasCorrectStructure() {
        let parent = FolderFixtures.createFolderHierarchy()

        XCTAssertEqual(parent.name, "Projects")
        XCTAssertEqual(parent.children.count, 2)

        let workFolder = parent.children.first { $0.name == "Work" }
        XCTAssertNotNil(workFolder)
        XCTAssertEqual(workFolder?.parent?.name, "Projects")
        XCTAssertEqual(workFolder?.children.count, 1)

        let activeFolder = workFolder?.children.first
        XCTAssertEqual(activeFolder?.name, "Active")
        XCTAssertEqual(activeFolder?.parent?.name, "Work")
    }

    func test_folderWithUnread_hasCorrectCounts() {
        let folder = FolderFixtures.createFolderWithUnread(unreadCount: 50, totalCount: 200)

        XCTAssertEqual(folder.unreadCount, 50)
        XCTAssertEqual(folder.totalCount, 200)
    }

    func test_emptyFolder_hasZeroCounts() {
        let folder = FolderFixtures.createEmptyFolder()

        XCTAssertEqual(folder.unreadCount, 0)
        XCTAssertEqual(folder.totalCount, 0)
    }

    func test_containerFolder_isNotSelectable() {
        let folder = FolderFixtures.createContainerFolder()

        XCTAssertFalse(folder.isSelectable)
    }

    func test_unsubscribedFolder_isNotSubscribed() {
        let folder = FolderFixtures.createUnsubscribedFolder()

        XCTAssertFalse(folder.isSubscribed)
    }

    func test_multipleFolders_areCreated() {
        let folders = FolderFixtures.createMultipleFolders(count: 5)

        XCTAssertEqual(folders.count, 5)

        // Each should have unique path
        let paths = Set(folders.map { $0.path })
        XCTAssertEqual(paths.count, 5)
    }
}
