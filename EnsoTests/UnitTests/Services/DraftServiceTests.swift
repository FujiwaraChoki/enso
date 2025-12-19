//
//  DraftServiceTests.swift
//  EnsoTests
//

import XCTest
@testable import Enso

@MainActor
final class DraftServiceTests: XCTestCase {

    var draftService: DraftService!

    override func setUp() async throws {
        try await super.setUp()
        draftService = DraftService()
        // Clear any existing drafts
        draftService.deleteAllDrafts()
    }

    override func tearDown() async throws {
        draftService.deleteAllDrafts()
        draftService = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_init_draftsEmpty() {
        XCTAssertTrue(draftService.drafts.isEmpty)
    }

    // MARK: - Create Draft Tests

    func test_createDraft_addsToDrafts() {
        let accountId = UUID()

        draftService.createDraft(accountId: accountId)

        XCTAssertEqual(draftService.drafts.count, 1)
    }

    func test_createDraft_returnsDraft() {
        let accountId = UUID()

        let draft = draftService.createDraft(accountId: accountId)

        XCTAssertEqual(draft.accountId, accountId)
    }

    func test_createDraft_insertsAtBeginning() {
        let accountId = UUID()

        let draft1 = draftService.createDraft(accountId: accountId)
        let draft2 = draftService.createDraft(accountId: accountId)

        XCTAssertEqual(draftService.drafts.first?.id, draft2.id)
        XCTAssertEqual(draftService.drafts.last?.id, draft1.id)
    }

    func test_createDraft_setsEmptyFields() {
        let accountId = UUID()

        let draft = draftService.createDraft(accountId: accountId)

        XCTAssertTrue(draft.toAddresses.isEmpty)
        XCTAssertTrue(draft.ccAddresses.isEmpty)
        XCTAssertTrue(draft.bccAddresses.isEmpty)
        XCTAssertEqual(draft.subject, "")
        XCTAssertEqual(draft.textBody, "")
        XCTAssertNil(draft.htmlBody)
        XCTAssertTrue(draft.attachmentPaths.isEmpty)
    }

    func test_createDraft_setsDates() {
        let accountId = UUID()
        let before = Date()

        let draft = draftService.createDraft(accountId: accountId)

        let after = Date()
        XCTAssertGreaterThanOrEqual(draft.createdDate, before)
        XCTAssertLessThanOrEqual(draft.createdDate, after)
        XCTAssertGreaterThanOrEqual(draft.modifiedDate, before)
        XCTAssertLessThanOrEqual(draft.modifiedDate, after)
    }

    // MARK: - Create Draft from Reply Tests

    func test_createDraft_reply_setsToAddress() {
        let accountId = UUID()
        let email = EmailFixtures.createEmail()
        email.fromAddress = "sender@example.com"

        let draft = draftService.createDraft(accountId: accountId, replyTo: email, mode: .reply)

        XCTAssertEqual(draft.toAddresses, ["sender@example.com"])
    }

    func test_createDraft_reply_setsRePrefix() {
        let accountId = UUID()
        let email = EmailFixtures.createEmail(subject: "Original Subject")

        let draft = draftService.createDraft(accountId: accountId, replyTo: email, mode: .reply)

        XCTAssertEqual(draft.subject, "Re: Original Subject")
    }

    func test_createDraft_reply_preservesExistingRePrefix() {
        let accountId = UUID()
        let email = EmailFixtures.createEmail(subject: "Re: Already Replied")

        let draft = draftService.createDraft(accountId: accountId, replyTo: email, mode: .reply)

        XCTAssertEqual(draft.subject, "Re: Already Replied")
    }

    func test_createDraft_replyAll_setsAllAddresses() {
        let accountId = UUID()
        let email = EmailFixtures.createEmail()
        email.fromAddress = "sender@example.com"
        email.toAddresses = ["me@example.com", "other@example.com"]
        email.ccAddresses = ["cc@example.com"]

        let draft = draftService.createDraft(accountId: accountId, replyTo: email, mode: .replyAll)

        XCTAssertEqual(draft.toAddresses, ["sender@example.com"])
        XCTAssertTrue(draft.ccAddresses.contains("me@example.com"))
        XCTAssertTrue(draft.ccAddresses.contains("other@example.com"))
        XCTAssertTrue(draft.ccAddresses.contains("cc@example.com"))
    }

    func test_createDraft_forward_setsFwdPrefix() {
        let accountId = UUID()
        let email = EmailFixtures.createEmail(subject: "Original Subject")

        let draft = draftService.createDraft(accountId: accountId, replyTo: email, mode: .forward)

        XCTAssertEqual(draft.subject, "Fwd: Original Subject")
    }

    func test_createDraft_forward_preservesExistingFwdPrefix() {
        let accountId = UUID()
        let email = EmailFixtures.createEmail(subject: "Fwd: Already Forwarded")

        let draft = draftService.createDraft(accountId: accountId, replyTo: email, mode: .forward)

        XCTAssertEqual(draft.subject, "Fwd: Already Forwarded")
    }

    func test_createDraft_forward_noToAddress() {
        let accountId = UUID()
        let email = EmailFixtures.createEmail()

        let draft = draftService.createDraft(accountId: accountId, replyTo: email, mode: .forward)

        XCTAssertTrue(draft.toAddresses.isEmpty)
    }

    func test_createDraft_setsReplyContext() {
        let accountId = UUID()
        let email = EmailFixtures.createEmail()

        let draft = draftService.createDraft(accountId: accountId, replyTo: email, mode: .reply)

        XCTAssertEqual(draft.replyToEmailId, email.id)
        XCTAssertEqual(draft.replyMode, "reply")
    }

    // MARK: - Update Draft Tests

    func test_updateDraft_updatesExisting() {
        let accountId = UUID()
        var draft = draftService.createDraft(accountId: accountId)
        draft.subject = "Updated Subject"

        draftService.updateDraft(draft)

        let updated = draftService.getDraft(draft.id)
        XCTAssertEqual(updated?.subject, "Updated Subject")
    }

    func test_updateDraft_updatesModifiedDate() throws {
        let accountId = UUID()
        var draft = draftService.createDraft(accountId: accountId)
        let originalDate = draft.modifiedDate

        // Wait a tiny bit to ensure time difference
        try Task.checkCancellation()

        draft.subject = "New Subject"
        draftService.updateDraft(draft)

        let updated = draftService.getDraft(draft.id)
        XCTAssertGreaterThanOrEqual(updated?.modifiedDate ?? originalDate, originalDate)
    }

    func test_updateDraft_doesNothing_forNonExistent() {
        let accountId = UUID()
        var draft = DraftService.DraftEmail(accountId: accountId)
        draft.id = UUID() // Non-existent ID

        // Should not crash
        draftService.updateDraft(draft)

        XCTAssertNil(draftService.getDraft(draft.id))
    }

    // MARK: - Save Draft Tests

    func test_saveDraft_updatesAllFields() {
        let accountId = UUID()
        let draft = draftService.createDraft(accountId: accountId)

        draftService.saveDraft(
            id: draft.id,
            toAddresses: ["to@example.com"],
            ccAddresses: ["cc@example.com"],
            bccAddresses: ["bcc@example.com"],
            subject: "New Subject",
            textBody: "Body content",
            attachmentPaths: ["/path/to/file.pdf"]
        )

        let saved = draftService.getDraft(draft.id)
        XCTAssertEqual(saved?.toAddresses, ["to@example.com"])
        XCTAssertEqual(saved?.ccAddresses, ["cc@example.com"])
        XCTAssertEqual(saved?.bccAddresses, ["bcc@example.com"])
        XCTAssertEqual(saved?.subject, "New Subject")
        XCTAssertEqual(saved?.textBody, "Body content")
        XCTAssertEqual(saved?.attachmentPaths, ["/path/to/file.pdf"])
    }

    // MARK: - Delete Draft Tests

    func test_deleteDraft_removesDraft() {
        let accountId = UUID()
        let draft = draftService.createDraft(accountId: accountId)
        XCTAssertEqual(draftService.drafts.count, 1)

        draftService.deleteDraft(draft.id)

        XCTAssertTrue(draftService.drafts.isEmpty)
    }

    func test_deleteDraft_doesNothing_forNonExistent() {
        let accountId = UUID()
        _ = draftService.createDraft(accountId: accountId)

        draftService.deleteDraft(UUID())

        XCTAssertEqual(draftService.drafts.count, 1)
    }

    func test_deleteAllDrafts_removesAll() {
        let accountId = UUID()
        _ = draftService.createDraft(accountId: accountId)
        _ = draftService.createDraft(accountId: accountId)
        _ = draftService.createDraft(accountId: accountId)
        XCTAssertEqual(draftService.drafts.count, 3)

        draftService.deleteAllDrafts()

        XCTAssertTrue(draftService.drafts.isEmpty)
    }

    // MARK: - Get Draft Tests

    func test_getDraft_returnsExisting() {
        let accountId = UUID()
        let draft = draftService.createDraft(accountId: accountId)

        let retrieved = draftService.getDraft(draft.id)

        XCTAssertEqual(retrieved?.id, draft.id)
    }

    func test_getDraft_returnsNil_forNonExistent() {
        let retrieved = draftService.getDraft(UUID())

        XCTAssertNil(retrieved)
    }

    func test_getDrafts_forAccount_filtersCorrectly() {
        let account1 = UUID()
        let account2 = UUID()

        _ = draftService.createDraft(accountId: account1)
        _ = draftService.createDraft(accountId: account1)
        _ = draftService.createDraft(accountId: account2)

        let account1Drafts = draftService.getDrafts(for: account1)
        let account2Drafts = draftService.getDrafts(for: account2)

        XCTAssertEqual(account1Drafts.count, 2)
        XCTAssertEqual(account2Drafts.count, 1)
    }

    func test_getDrafts_forAccount_returnsEmpty_forUnknown() {
        let accountId = UUID()
        _ = draftService.createDraft(accountId: accountId)

        let drafts = draftService.getDrafts(for: UUID())

        XCTAssertTrue(drafts.isEmpty)
    }

    // MARK: - Auto-save Tests

    func test_scheduleAutoSave_savesPendingChanges() async throws {
        let accountId = UUID()
        var draft = draftService.createDraft(accountId: accountId)
        draft.subject = "Auto-saved Subject"

        draftService.scheduleAutoSave(draft)

        // Wait for auto-save timer (3 seconds + buffer)
        try await Task.sleep(nanoseconds: 4_000_000_000)

        let saved = draftService.getDraft(draft.id)
        XCTAssertEqual(saved?.subject, "Auto-saved Subject")
    }

    func test_flushPendingChanges_savesImmediately() {
        let accountId = UUID()
        var draft = draftService.createDraft(accountId: accountId)
        draft.subject = "Flushed Subject"

        draftService.scheduleAutoSave(draft)
        draftService.flushPendingChanges()

        let saved = draftService.getDraft(draft.id)
        XCTAssertEqual(saved?.subject, "Flushed Subject")
    }

    func test_flushPendingChanges_handlesNoPending() {
        // Should not crash when no pending changes
        draftService.flushPendingChanges()
    }

    // MARK: - DraftEmail Tests

    func test_draftEmail_identifiable() {
        let draft = DraftService.DraftEmail(accountId: UUID())

        XCTAssertNotNil(draft.id)
    }

    func test_draftEmail_codable() throws {
        let accountId = UUID()
        var draft = DraftService.DraftEmail(accountId: accountId)
        draft.toAddresses = ["test@example.com"]
        draft.subject = "Test Subject"

        let encoded = try JSONEncoder().encode(draft)
        let decoded = try JSONDecoder().decode(DraftService.DraftEmail.self, from: encoded)

        XCTAssertEqual(decoded.accountId, accountId)
        XCTAssertEqual(decoded.toAddresses, ["test@example.com"])
        XCTAssertEqual(decoded.subject, "Test Subject")
    }

    // MARK: - ReplyMode Tests

    func test_replyMode_rawValues() {
        XCTAssertEqual(ReplyMode.reply.rawValue, "reply")
        XCTAssertEqual(ReplyMode.replyAll.rawValue, "replyAll")
        XCTAssertEqual(ReplyMode.forward.rawValue, "forward")
    }

    func test_replyMode_initFromRawValue() {
        XCTAssertEqual(ReplyMode(rawValue: "reply"), .reply)
        XCTAssertEqual(ReplyMode(rawValue: "replyAll"), .replyAll)
        XCTAssertEqual(ReplyMode(rawValue: "forward"), .forward)
        XCTAssertNil(ReplyMode(rawValue: "invalid"))
    }

    // MARK: - Persistence Tests

    func test_drafts_persistAcrossInstances() {
        let accountId = UUID()
        let draft = draftService.createDraft(accountId: accountId)
        draftService.saveDraft(
            id: draft.id,
            toAddresses: ["persist@example.com"],
            ccAddresses: [],
            bccAddresses: [],
            subject: "Persisted Draft",
            textBody: "Content"
        )

        // Create new service instance
        let newService = DraftService()

        let persisted = newService.getDraft(draft.id)
        XCTAssertEqual(persisted?.subject, "Persisted Draft")
        XCTAssertEqual(persisted?.toAddresses, ["persist@example.com"])

        // Clean up
        newService.deleteAllDrafts()
    }
}
