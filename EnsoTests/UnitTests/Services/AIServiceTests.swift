//
//  AIServiceTests.swift
//  EnsoTests
//

import XCTest
@testable import Enso

@MainActor
final class AIServiceTests: XCTestCase {

    var mockAIService: MockAIService!

    override func setUp() async throws {
        try await super.setUp()
        mockAIService = MockAIService()
    }

    override func tearDown() async throws {
        mockAIService.reset()
        mockAIService = nil
        try await super.tearDown()
    }

    // MARK: - Availability Tests

    func test_isAvailable_defaultsToTrue() {
        XCTAssertTrue(mockAIService.isAvailable)
    }

    func test_simulateUnavailable_setsIsAvailableFalse() {
        mockAIService.simulateUnavailable()

        XCTAssertFalse(mockAIService.isAvailable)
    }

    func test_checkAvailability_incrementsCallCount() async {
        await mockAIService.checkAvailability()

        XCTAssertEqual(mockAIService.checkAvailabilityCallCount, 1)
    }

    // MARK: - Session Tests

    func test_createSession_incrementsCallCount() async throws {
        try await mockAIService.createSession(withSystemPrompt: nil)

        XCTAssertEqual(mockAIService.createSessionCallCount, 1)
    }

    func test_createSession_storesSystemPrompt() async throws {
        let prompt = "You are a helpful assistant."

        try await mockAIService.createSession(withSystemPrompt: prompt)

        XCTAssertEqual(mockAIService.lastSystemPrompt, prompt)
    }

    func test_createSession_throwsError_whenConfigured() async {
        mockAIService.shouldThrowOnCreateSession = .sessionNotAvailable

        do {
            try await mockAIService.createSession(withSystemPrompt: nil)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is AIService.AIError)
        }
    }

    // MARK: - Message Tests

    func test_sendMessage_addsUserMessage() async throws {
        _ = try await mockAIService.sendMessage("Hello")

        XCTAssertEqual(mockAIService.messages.count, 2) // User + Assistant
        XCTAssertEqual(mockAIService.messages[0].role, .user)
        XCTAssertEqual(mockAIService.messages[0].content, "Hello")
    }

    func test_sendMessage_addsAssistantResponse() async throws {
        mockAIService.mockResponse = "Hi there!"

        let response = try await mockAIService.sendMessage("Hello")

        XCTAssertEqual(response, "Hi there!")
        XCTAssertEqual(mockAIService.messages[1].role, .assistant)
        XCTAssertEqual(mockAIService.messages[1].content, "Hi there!")
    }

    func test_sendMessage_incrementsCallCount() async throws {
        _ = try await mockAIService.sendMessage("Test")

        XCTAssertEqual(mockAIService.sendMessageCallCount, 1)
    }

    func test_sendMessage_storesLastReceivedMessage() async throws {
        _ = try await mockAIService.sendMessage("Test message")

        XCTAssertEqual(mockAIService.lastReceivedMessage, "Test message")
    }

    func test_sendMessage_throwsError_whenConfigured() async {
        mockAIService.shouldThrowOnSendMessage = .generationFailed(NSError(domain: "Test", code: 1))

        do {
            _ = try await mockAIService.sendMessage("Test")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is AIService.AIError)
        }
    }

    // MARK: - Email Context Tests

    func test_setEmailContext_storesEmail() {
        let email = EmailFixtures.createEmail()

        mockAIService.setEmailContext(email)

        XCTAssertEqual(mockAIService.lastEmailContext?.id, email.id)
    }

    func test_setEmailContext_acceptsNil() {
        let email = EmailFixtures.createEmail()
        mockAIService.setEmailContext(email)

        mockAIService.setEmailContext(nil)

        XCTAssertNil(mockAIService.lastEmailContext)
    }

    // MARK: - Conversation Tests

    func test_clearConversation_removesAllMessages() async throws {
        _ = try await mockAIService.sendMessage("First")
        _ = try await mockAIService.sendMessage("Second")
        XCTAssertEqual(mockAIService.messages.count, 4)

        mockAIService.clearConversation()

        XCTAssertTrue(mockAIService.messages.isEmpty)
    }

    func test_clearConversation_clearsCurrentStreamText() async {
        mockAIService.simulateGenerating(true)

        mockAIService.clearConversation()

        XCTAssertEqual(mockAIService.currentStreamText, "")
    }

    func test_clearConversation_resetsResponseType() async throws {
        _ = try await mockAIService.summarizeEmail(EmailFixtures.createEmail())
        XCTAssertEqual(mockAIService.lastResponseType, .summary)

        mockAIService.clearConversation()

        XCTAssertEqual(mockAIService.lastResponseType, .none)
    }

    // MARK: - Summarize Tests

    func test_summarizeEmail_returnsConfiguredResponse() async throws {
        let email = EmailFixtures.createEmail()
        mockAIService.mockSummary = "Custom summary"

        let result = try await mockAIService.summarizeEmail(email)

        XCTAssertEqual(result, "Custom summary")
    }

    func test_summarizeEmail_incrementsCallCount() async throws {
        _ = try await mockAIService.summarizeEmail(EmailFixtures.createEmail())

        XCTAssertEqual(mockAIService.summarizeEmailCallCount, 1)
    }

    func test_summarizeEmail_setsResponseType() async throws {
        _ = try await mockAIService.summarizeEmail(EmailFixtures.createEmail())

        XCTAssertEqual(mockAIService.lastResponseType, .summary)
    }

    func test_summarizeEmail_throwsError_whenConfigured() async {
        mockAIService.shouldThrowOnSummarize = .unsupportedLanguage

        do {
            _ = try await mockAIService.summarizeEmail(EmailFixtures.createEmail())
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }
    }

    // MARK: - Generate Reply Tests

    func test_generateReply_returnsConfiguredResponse() async throws {
        let email = EmailFixtures.createEmail()
        mockAIService.mockReply = "Custom reply"

        let result = try await mockAIService.generateReply(to: email, tone: "professional")

        XCTAssertEqual(result, "Custom reply")
    }

    func test_generateReply_storesLastTone() async throws {
        _ = try await mockAIService.generateReply(to: EmailFixtures.createEmail(), tone: "friendly")

        XCTAssertEqual(mockAIService.lastReplyTone, "friendly")
    }

    func test_generateReply_setsResponseType() async throws {
        _ = try await mockAIService.generateReply(to: EmailFixtures.createEmail(), tone: "formal")

        XCTAssertEqual(mockAIService.lastResponseType, .draftReply)
    }

    // MARK: - Improve Writing Tests

    func test_improveWriting_returnsConfiguredResponse() async throws {
        mockAIService.mockImprovedWriting = "Better text"

        let result = try await mockAIService.improveWriting("Original text", instruction: "Make it better")

        XCTAssertEqual(result, "Better text")
    }

    func test_improveWriting_storesTextAndInstruction() async throws {
        _ = try await mockAIService.improveWriting("Test text", instruction: "Fix grammar")

        XCTAssertEqual(mockAIService.lastImproveWritingText, "Test text")
        XCTAssertEqual(mockAIService.lastImproveWritingInstruction, "Fix grammar")
    }

    // MARK: - Action Items Tests

    func test_extractActionItems_returnsConfiguredResponse() async throws {
        mockAIService.mockActionItems = "- Task 1\n- Task 2"

        let result = try await mockAIService.extractActionItems(from: EmailFixtures.createEmail())

        XCTAssertEqual(result, "- Task 1\n- Task 2")
    }

    func test_extractActionItems_setsResponseType() async throws {
        _ = try await mockAIService.extractActionItems(from: EmailFixtures.createEmail())

        XCTAssertEqual(mockAIService.lastResponseType, .actionItems)
    }

    // MARK: - Sentiment Tests

    func test_analyzeSentiment_returnsConfiguredResponse() async throws {
        mockAIService.mockSentiment = "Positive tone"

        let result = try await mockAIService.analyzeSentiment(of: EmailFixtures.createEmail())

        XCTAssertEqual(result, "Positive tone")
    }

    // MARK: - Helper Tests

    func test_userMessages_filtersCorrectly() async throws {
        _ = try await mockAIService.sendMessage("User 1")
        _ = try await mockAIService.sendMessage("User 2")

        XCTAssertEqual(mockAIService.userMessages.count, 2)
        XCTAssertTrue(mockAIService.userMessages.allSatisfy { $0.role == .user })
    }

    func test_assistantMessages_filtersCorrectly() async throws {
        _ = try await mockAIService.sendMessage("Message 1")
        _ = try await mockAIService.sendMessage("Message 2")

        XCTAssertEqual(mockAIService.assistantMessages.count, 2)
        XCTAssertTrue(mockAIService.assistantMessages.allSatisfy { $0.role == .assistant })
    }

    // MARK: - Reset Tests

    func test_reset_clearsAllState() async throws {
        _ = try await mockAIService.sendMessage("Test")
        mockAIService.setEmailContext(EmailFixtures.createEmail())
        mockAIService.simulateUnavailable()

        mockAIService.reset()

        XCTAssertTrue(mockAIService.isAvailable)
        XCTAssertTrue(mockAIService.messages.isEmpty)
        XCTAssertNil(mockAIService.lastEmailContext)
        XCTAssertEqual(mockAIService.sendMessageCallCount, 0)
    }
}
