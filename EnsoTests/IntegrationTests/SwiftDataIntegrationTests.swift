//
//  SwiftDataIntegrationTests.swift
//  EnsoTests
//

import XCTest
import SwiftData
@testable import Enso

@MainActor
final class SwiftDataIntegrationTests: XCTestCase {

    var testContainer: SwiftDataTestContainer!

    override func setUp() async throws {
        try await super.setUp()
        testContainer = try SwiftDataTestContainer()
    }

    override func tearDown() async throws {
        try testContainer.reset()
        testContainer = nil
        try await super.tearDown()
    }

    // MARK: - Account-Folder Relationship Tests

    func test_accountWithFolders_establishesRelationship() throws {
        let account = AccountFixtures.createAccount()
        let inbox = FolderFixtures.createInbox()
        inbox.account = account

        testContainer.insert(account)
        testContainer.insert(inbox)
        try testContainer.save()

        let fetchedAccounts = try testContainer.fetch(Account.self)
        XCTAssertEqual(fetchedAccounts.count, 1)
        XCTAssertEqual(fetchedAccounts.first?.folders.count, 1)
    }

    func test_multipleFolders_forAccount() throws {
        let account = AccountFixtures.createAccount()
        let folders = FolderFixtures.createStandardFolderSet()

        testContainer.insert(account)
        for folder in folders {
            folder.account = account
            testContainer.insert(folder)
        }
        try testContainer.save()

        let fetchedAccount = try testContainer.fetch(Account.self).first
        XCTAssertEqual(fetchedAccount?.folders.count, 4)
    }

    // MARK: - Account-Email Relationship Tests

    func test_accountWithEmails_establishesRelationship() throws {
        let account = AccountFixtures.createAccount()
        let inbox = FolderFixtures.createInbox()
        inbox.account = account
        let email = EmailFixtures.createEmail()
        email.account = account
        email.folder = inbox

        testContainer.insert(account)
        testContainer.insert(inbox)
        testContainer.insert(email)
        try testContainer.save()

        let fetchedAccount = try testContainer.fetch(Account.self).first
        XCTAssertEqual(fetchedAccount?.emails.count, 1)
    }

    // MARK: - Folder-Email Relationship Tests

    func test_folderWithEmails_establishesRelationship() throws {
        let account = AccountFixtures.createAccount()
        let inbox = FolderFixtures.createInbox()
        inbox.account = account
        let emails = EmailFixtures.createMultipleEmails(count: 5)

        testContainer.insert(account)
        testContainer.insert(inbox)
        for email in emails {
            email.account = account
            email.folder = inbox
            testContainer.insert(email)
        }
        try testContainer.save()

        let fetchedFolders = try testContainer.fetch(Folder.self)
        XCTAssertEqual(fetchedFolders.first?.emails.count, 5)
    }

    // MARK: - Email-Attachment Relationship Tests

    func test_emailWithAttachments_establishesRelationship() throws {
        let email = EmailFixtures.createEmailWithAttachments()
        let attachments = AttachmentFixtures.createMultipleAttachments(count: 3)

        testContainer.insert(email)
        for attachment in attachments {
            attachment.email = email
            testContainer.insert(attachment)
        }
        try testContainer.save()

        let fetchedEmail = try testContainer.fetch(Email.self).first
        XCTAssertEqual(fetchedEmail?.attachments.count, 3)
    }

    // MARK: - Cascade Delete Tests

    func test_deleteAccount_cascadesDeleteFolders() throws {
        let account = AccountFixtures.createAccount()
        let inbox = FolderFixtures.createInbox()
        inbox.account = account

        testContainer.insert(account)
        testContainer.insert(inbox)
        try testContainer.save()

        // Verify folder exists
        XCTAssertEqual(try testContainer.count(Folder.self), 1)

        // Delete account
        testContainer.delete(account)
        try testContainer.save()

        // Verify folder was cascaded
        XCTAssertEqual(try testContainer.count(Folder.self), 0)
    }

    func test_deleteAccount_cascadesDeleteEmails() throws {
        let account = AccountFixtures.createAccount()
        let email = EmailFixtures.createEmail()
        email.account = account

        testContainer.insert(account)
        testContainer.insert(email)
        try testContainer.save()

        // Delete account
        testContainer.delete(account)
        try testContainer.save()

        // Verify email was cascaded
        XCTAssertEqual(try testContainer.count(Email.self), 0)
    }

    func test_deleteEmail_cascadesDeleteAttachments() throws {
        let email = EmailFixtures.createEmail()
        let attachment = AttachmentFixtures.createPDFAttachment()
        attachment.email = email

        testContainer.insert(email)
        testContainer.insert(attachment)
        try testContainer.save()

        // Verify attachment exists
        XCTAssertEqual(try testContainer.count(Attachment.self), 1)

        // Delete email
        testContainer.delete(email)
        try testContainer.save()

        // Verify attachment was cascaded
        XCTAssertEqual(try testContainer.count(Attachment.self), 0)
    }

    func test_deleteFolder_cascadesDeleteEmails() throws {
        let account = AccountFixtures.createAccount()
        let inbox = FolderFixtures.createInbox()
        inbox.account = account
        let email = EmailFixtures.createEmail()
        email.folder = inbox
        email.account = account

        testContainer.insert(account)
        testContainer.insert(inbox)
        testContainer.insert(email)
        try testContainer.save()

        // Delete folder
        testContainer.delete(inbox)
        try testContainer.save()

        // Verify email was cascaded
        XCTAssertEqual(try testContainer.count(Email.self), 0)
    }

    // MARK: - Folder Hierarchy Tests

    func test_folderHierarchy_parentChildRelationship() throws {
        let account = AccountFixtures.createAccount()
        let parent = FolderFixtures.createCustomFolder(name: "Parent")
        parent.account = account
        let child = FolderFixtures.createCustomFolder(name: "Child")
        child.account = account
        child.parent = parent

        testContainer.insert(account)
        testContainer.insert(parent)
        testContainer.insert(child)
        try testContainer.save()

        let fetchedParent = try testContainer.fetch(Folder.self).first { $0.name == "Parent" }
        XCTAssertEqual(fetchedParent?.children.count, 1)
        XCTAssertEqual(fetchedParent?.children.first?.name, "Child")
    }

    func test_deleteParentFolder_cascadesDeleteChildren() throws {
        let account = AccountFixtures.createAccount()
        let parent = FolderFixtures.createCustomFolder(name: "Parent")
        parent.account = account
        let child = FolderFixtures.createCustomFolder(name: "Child")
        child.account = account
        child.parent = parent

        testContainer.insert(account)
        testContainer.insert(parent)
        testContainer.insert(child)
        try testContainer.save()

        // Delete parent
        testContainer.delete(parent)
        try testContainer.save()

        // Verify child was cascaded (only account folder remains from cascade cleanup)
        // Note: The parent folder deletion should cascade to children
        let remainingFolders = try testContainer.fetch(Folder.self)
        XCTAssertFalse(remainingFolders.contains { $0.name == "Child" })
    }

    // MARK: - Query Tests

    func test_fetchEmails_sortedByDate() throws {
        let emails = (1...5).map { index -> Email in
            let email = EmailFixtures.createEmail(uid: UInt32(index))
            email.date = Date().addingTimeInterval(Double(-index) * 3600)
            return email
        }

        for email in emails {
            testContainer.insert(email)
        }
        try testContainer.save()

        let fetchedEmails = try testContainer.fetch(
            Email.self,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        // Most recent first
        XCTAssertEqual(fetchedEmails.first?.uid, 1)
        XCTAssertEqual(fetchedEmails.last?.uid, 5)
    }

    func test_fetchUnreadEmails() throws {
        let readEmail = EmailFixtures.createReadEmail()
        let unreadEmail = EmailFixtures.createUnreadEmail()

        testContainer.insert(readEmail)
        testContainer.insert(unreadEmail)
        try testContainer.save()

        let unreadPredicate = #Predicate<Email> { !$0.isRead }
        let unreadEmails = try testContainer.fetch(Email.self, predicate: unreadPredicate)

        XCTAssertEqual(unreadEmails.count, 1)
        XCTAssertFalse(unreadEmails.first?.isRead ?? true)
    }

    func test_fetchStarredEmails() throws {
        let regularEmail = EmailFixtures.createEmail()
        let starredEmail = EmailFixtures.createStarredEmail()

        testContainer.insert(regularEmail)
        testContainer.insert(starredEmail)
        try testContainer.save()

        let starredPredicate = #Predicate<Email> { $0.isStarred }
        let starredEmails = try testContainer.fetch(Email.self, predicate: starredPredicate)

        XCTAssertEqual(starredEmails.count, 1)
        XCTAssertTrue(starredEmails.first?.isStarred ?? false)
    }

    // MARK: - Count Tests

    func test_countEmails() throws {
        let emails = EmailFixtures.createMultipleEmails(count: 10)
        for email in emails {
            testContainer.insert(email)
        }
        try testContainer.save()

        let count = try testContainer.count(Email.self)
        XCTAssertEqual(count, 10)
    }

    func test_countWithPredicate() throws {
        let emails = EmailFixtures.createMixedStatusEmails(count: 10)
        for email in emails {
            testContainer.insert(email)
        }
        try testContainer.save()

        let unreadPredicate = #Predicate<Email> { !$0.isRead }
        let unreadCount = try testContainer.count(Email.self, predicate: unreadPredicate)

        // Based on createMixedStatusEmails: index % 2 == 0 is read
        XCTAssertEqual(unreadCount, 5)
    }

    // MARK: - Update Tests

    func test_updateEmailFlags() throws {
        let email = EmailFixtures.createUnreadEmail()
        testContainer.insert(email)
        try testContainer.save()

        // Update
        email.isRead = true
        email.isStarred = true
        try testContainer.save()

        // Verify
        let fetchedEmail = try testContainer.fetch(Email.self).first
        XCTAssertTrue(fetchedEmail?.isRead ?? false)
        XCTAssertTrue(fetchedEmail?.isStarred ?? false)
    }

    func test_updateFolderCounts() throws {
        let folder = FolderFixtures.createInbox(unreadCount: 5, totalCount: 100)
        testContainer.insert(folder)
        try testContainer.save()

        // Update
        folder.unreadCount = 3
        folder.totalCount = 105
        try testContainer.save()

        // Verify
        let fetchedFolder = try testContainer.fetch(Folder.self).first
        XCTAssertEqual(fetchedFolder?.unreadCount, 3)
        XCTAssertEqual(fetchedFolder?.totalCount, 105)
    }

    // MARK: - AI Models Tests

    func test_aiConversation_withMessages() throws {
        let conversation = AIConversation(contextType: .general)
        let message1 = AIMessage(role: .user, content: "Hello")
        let message2 = AIMessage(role: .assistant, content: "Hi there!")
        message1.conversation = conversation
        message2.conversation = conversation

        testContainer.insert(conversation)
        testContainer.insert(message1)
        testContainer.insert(message2)
        try testContainer.save()

        let fetchedConversation = try testContainer.fetch(AIConversation.self).first
        XCTAssertEqual(fetchedConversation?.messages.count, 2)
    }

    func test_deleteConversation_cascadesDeleteMessages() throws {
        let conversation = AIConversation(contextType: .general)
        let message = AIMessage(role: .user, content: "Test")
        message.conversation = conversation

        testContainer.insert(conversation)
        testContainer.insert(message)
        try testContainer.save()

        // Delete conversation
        testContainer.delete(conversation)
        try testContainer.save()

        // Verify message was cascaded
        XCTAssertEqual(try testContainer.count(AIMessage.self), 0)
    }

    // MARK: - Reset Tests

    func test_reset_deletesAllEntities() throws {
        // Insert various entities
        let account = AccountFixtures.createAccount()
        let folder = FolderFixtures.createInbox()
        folder.account = account
        let email = EmailFixtures.createEmail()
        email.account = account
        email.folder = folder
        let attachment = AttachmentFixtures.createPDFAttachment()
        attachment.email = email

        testContainer.insert(account)
        testContainer.insert(folder)
        testContainer.insert(email)
        testContainer.insert(attachment)
        try testContainer.save()

        // Reset
        try testContainer.reset()

        // Verify all empty
        XCTAssertEqual(try testContainer.count(Account.self), 0)
        XCTAssertEqual(try testContainer.count(Folder.self), 0)
        XCTAssertEqual(try testContainer.count(Email.self), 0)
        XCTAssertEqual(try testContainer.count(Attachment.self), 0)
    }
}
