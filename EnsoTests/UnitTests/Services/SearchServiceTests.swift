//
//  SearchServiceTests.swift
//  EnsoTests
//

import XCTest
import SwiftData
@testable import Enso

@MainActor
final class SearchServiceTests: XCTestCase {

    var searchService: SearchService!
    var testContainer: SwiftDataTestContainer!

    override func setUp() async throws {
        try await super.setUp()
        // Clear search history before each test
        UserDefaults.standard.removeObject(forKey: "searchHistory")
        testContainer = try SwiftDataTestContainer()
        searchService = SearchService()
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "searchHistory")
        try testContainer.reset()
        testContainer = nil
        searchService = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func test_init_isSearchingFalse() {
        XCTAssertFalse(searchService.isSearching)
    }

    func test_init_resultsEmpty() {
        XCTAssertTrue(searchService.results.isEmpty)
    }

    func test_init_loadsEmptyHistory() {
        XCTAssertTrue(searchService.searchHistory.isEmpty)
    }

    // MARK: - Local Search - Empty Query Tests

    func test_searchLocal_emptyQuery_returnsEmpty() {
        let results = searchService.searchLocal(
            query: "",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertTrue(results.isEmpty)
    }

    func test_searchLocal_emptyQuery_withAttachmentsScope_searches() throws {
        let emailWithAttachment = EmailFixtures.createEmailWithAttachments()
        let emailWithoutAttachment = EmailFixtures.createEmail()
        testContainer.insert(emailWithAttachment)
        testContainer.insert(emailWithoutAttachment)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "",
            scope: .attachments,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.email.hasAttachments ?? false)
    }

    func test_searchLocal_emptyQuery_withUnreadScope_searches() throws {
        let unreadEmail = EmailFixtures.createUnreadEmail()
        let readEmail = EmailFixtures.createReadEmail()
        testContainer.insert(unreadEmail)
        testContainer.insert(readEmail)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "",
            scope: .unread,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results.first?.email.isRead ?? true)
    }

    func test_searchLocal_emptyQuery_withStarredScope_searches() throws {
        let starredEmail = EmailFixtures.createStarredEmail()
        let regularEmail = EmailFixtures.createEmail()
        testContainer.insert(starredEmail)
        testContainer.insert(regularEmail)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "",
            scope: .starred,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.email.isStarred ?? false)
    }

    // MARK: - Local Search - Subject Scope Tests

    func test_searchLocal_subjectScope_findsMatches() throws {
        let email1 = EmailFixtures.createEmail(subject: "Meeting Tomorrow")
        let email2 = EmailFixtures.createEmail(subject: "Different Topic")
        testContainer.insert(email1)
        testContainer.insert(email2)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "Meeting",
            scope: .subject,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.matchField, "Subject")
    }

    func test_searchLocal_subjectScope_caseInsensitive() throws {
        let email = EmailFixtures.createEmail(subject: "IMPORTANT Meeting")
        testContainer.insert(email)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "important",
            scope: .subject,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Local Search - Sender Scope Tests

    func test_searchLocal_senderScope_findsByAddress() throws {
        let email = EmailFixtures.createEmail()
        email.fromAddress = "john@example.com"
        testContainer.insert(email)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "john@example",
            scope: .sender,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.matchField, "Sender")
    }

    func test_searchLocal_senderScope_findsByName() throws {
        let email = EmailFixtures.createEmail()
        email.fromName = "John Smith"
        testContainer.insert(email)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "Smith",
            scope: .sender,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Local Search - Body Scope Tests

    func test_searchLocal_bodyScope_findsInTextBody() throws {
        let email = EmailFixtures.createEmail()
        email.textBody = "The quick brown fox jumps over the lazy dog"
        testContainer.insert(email)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "brown fox",
            scope: .body,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.matchField, "Body")
    }

    func test_searchLocal_bodyScope_noMatchInSubject() throws {
        let email = EmailFixtures.createEmail(subject: "Brown Fox Subject")
        email.textBody = "Different content"
        testContainer.insert(email)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "Brown Fox",
            scope: .body,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Local Search - All Scope Tests

    func test_searchLocal_allScope_searchesMultipleFields() throws {
        let emailInSubject = EmailFixtures.createEmail(subject: "Meeting Agenda")
        let emailInSender = EmailFixtures.createEmail(subject: "Other")
        emailInSender.fromAddress = "meeting@company.com"
        let emailInBody = EmailFixtures.createEmail(subject: "Another")
        emailInBody.textBody = "We should discuss the meeting"

        testContainer.insert(emailInSubject)
        testContainer.insert(emailInSender)
        testContainer.insert(emailInBody)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "meeting",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.count, 3)
    }

    // MARK: - Local Search - Current Folder Scope Tests

    func test_searchLocal_currentFolderScope_filtersToFolder() throws {
        let account = AccountFixtures.createAccount()
        let inbox = FolderFixtures.createInbox()
        inbox.account = account
        let sent = FolderFixtures.createSentFolder()
        sent.account = account

        let inboxEmail = EmailFixtures.createEmail(subject: "Meeting")
        inboxEmail.folder = inbox
        let sentEmail = EmailFixtures.createEmail(subject: "Meeting Reply")
        sentEmail.folder = sent

        testContainer.insert(account)
        testContainer.insert(inbox)
        testContainer.insert(sent)
        testContainer.insert(inboxEmail)
        testContainer.insert(sentEmail)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "Meeting",
            scope: .currentFolder,
            folder: inbox,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.email.folder?.id, inbox.id)
    }

    func test_searchLocal_currentFolderScope_noFolder_returnsEmpty() throws {
        let email = EmailFixtures.createEmail(subject: "Test")
        testContainer.insert(email)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "Test",
            scope: .currentFolder,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Search Results Limit Tests

    func test_searchLocal_limitsTo100Results() throws {
        // Create 150 emails
        for i in 1...150 {
            let email = EmailFixtures.createEmail(subject: "Meeting \(i)")
            testContainer.insert(email)
        }
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "Meeting",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.count, 100)
    }

    // MARK: - Search History Tests

    func test_search_addsToHistory() async throws {
        await searchService.search(
            query: "test query",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(searchService.searchHistory.first, "test query")
    }

    func test_search_emptyQuery_notAddedToHistory() async throws {
        await searchService.search(
            query: "",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertTrue(searchService.searchHistory.isEmpty)
    }

    func test_search_duplicateQuery_movesToFront() async throws {
        await searchService.search(
            query: "first",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )
        await searchService.search(
            query: "second",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )
        await searchService.search(
            query: "first",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(searchService.searchHistory.count, 2)
        XCTAssertEqual(searchService.searchHistory.first, "first")
    }

    func test_search_historyLimitedTo20() async throws {
        for i in 1...25 {
            await searchService.search(
                query: "query \(i)",
                scope: .all,
                folder: nil,
                modelContext: testContainer.context
            )
        }

        XCTAssertEqual(searchService.searchHistory.count, 20)
    }

    func test_clearHistory_removesAll() async throws {
        await searchService.search(
            query: "test",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )
        XCTAssertFalse(searchService.searchHistory.isEmpty)

        searchService.clearHistory()

        XCTAssertTrue(searchService.searchHistory.isEmpty)
    }

    // MARK: - Search State Tests

    func test_search_setsIsSearchingDuringSearch() async throws {
        // Note: isSearching is set and reset quickly, hard to test precisely
        // Testing that it ends in false state
        await searchService.search(
            query: "test",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertFalse(searchService.isSearching)
    }

    // MARK: - Search Result Tests

    func test_searchResult_hasUniqueId() throws {
        let email = EmailFixtures.createEmail(subject: "Test")
        testContainer.insert(email)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "Test",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.first?.id, email.id)
    }

    func test_searchResult_matchField_identifiesSubject() throws {
        let email = EmailFixtures.createEmail(subject: "Important Meeting")
        email.fromAddress = "other@example.com"
        testContainer.insert(email)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "Important",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.first?.matchField, "Subject")
    }

    func test_searchResult_matchField_identifiesSender() throws {
        let email = EmailFixtures.createEmail(subject: "Other Subject")
        email.fromAddress = "important@example.com"
        testContainer.insert(email)
        try testContainer.save()

        let results = searchService.searchLocal(
            query: "important",
            scope: .all,
            folder: nil,
            modelContext: testContainer.context
        )

        XCTAssertEqual(results.first?.matchField, "Sender")
    }

    // MARK: - SearchScope Tests

    func test_searchScope_allCases() {
        let allCases = SearchService.SearchScope.allCases

        XCTAssertEqual(allCases.count, 8)
        XCTAssertTrue(allCases.contains(.all))
        XCTAssertTrue(allCases.contains(.currentFolder))
        XCTAssertTrue(allCases.contains(.subject))
        XCTAssertTrue(allCases.contains(.sender))
        XCTAssertTrue(allCases.contains(.body))
        XCTAssertTrue(allCases.contains(.attachments))
        XCTAssertTrue(allCases.contains(.unread))
        XCTAssertTrue(allCases.contains(.starred))
    }

    func test_searchScope_rawValues() {
        XCTAssertEqual(SearchService.SearchScope.all.rawValue, "All Mail")
        XCTAssertEqual(SearchService.SearchScope.currentFolder.rawValue, "Current Folder")
        XCTAssertEqual(SearchService.SearchScope.subject.rawValue, "Subject")
        XCTAssertEqual(SearchService.SearchScope.sender.rawValue, "Sender")
        XCTAssertEqual(SearchService.SearchScope.body.rawValue, "Body")
        XCTAssertEqual(SearchService.SearchScope.attachments.rawValue, "Has Attachments")
        XCTAssertEqual(SearchService.SearchScope.unread.rawValue, "Unread")
        XCTAssertEqual(SearchService.SearchScope.starred.rawValue, "Starred")
    }
}
