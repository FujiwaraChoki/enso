//
//  MockAIService.swift
//  EnsoTests
//

import Foundation
@testable import Enso

/// Mock implementation of AIServiceProtocol for testing
@MainActor
final class MockAIService: AIServiceProtocol {

    // MARK: - State

    var isAvailable: Bool = true
    var isGenerating: Bool = false
    var currentStreamText: String = ""
    var messages: [AIService.Message] = []
    var lastResponseType: AIService.ResponseType = .none

    // MARK: - Configurable Responses

    var mockResponse: String = "This is a mock AI response."
    var mockSummary: String = "This email discusses important matters that require attention."
    var mockReply: String = "Thank you for your email. I will review this and get back to you shortly."
    var mockImprovedWriting: String = "Improved version of the text."
    var mockActionItems: String = "- Review the attached document\n- Schedule follow-up meeting\n- Send confirmation email"
    var mockSentiment: String = "The email has a professional and neutral tone."

    /// Delay in nanoseconds for streaming simulation
    var streamingDelay: UInt64 = 10_000_000 // 10ms

    // MARK: - Tracking

    private(set) var checkAvailabilityCallCount = 0
    private(set) var createSessionCallCount = 0
    private(set) var sendMessageCallCount = 0
    private(set) var sendMessageStreamingCallCount = 0
    private(set) var summarizeEmailCallCount = 0
    private(set) var generateReplyCallCount = 0
    private(set) var improveWritingCallCount = 0
    private(set) var extractActionItemsCallCount = 0
    private(set) var analyzeSentimentCallCount = 0

    private(set) var lastReceivedMessage: String?
    private(set) var lastEmailContext: Email?
    private(set) var lastSystemPrompt: String?
    private(set) var lastImproveWritingText: String?
    private(set) var lastImproveWritingInstruction: String?
    private(set) var lastReplyTone: String?

    // MARK: - Error Injection

    var shouldThrowOnCreateSession: AIService.AIError?
    var shouldThrowOnSendMessage: AIService.AIError?
    var shouldThrowOnSummarize: AIService.AIError?
    var shouldThrowOnGenerateReply: AIService.AIError?
    var shouldThrowOnImproveWriting: AIService.AIError?
    var shouldThrowOnExtractActionItems: AIService.AIError?
    var shouldThrowOnAnalyzeSentiment: AIService.AIError?

    // MARK: - Protocol Implementation

    func checkAvailability() async {
        checkAvailabilityCallCount += 1
        // isAvailable is already set via the property
    }

    func createSession(withSystemPrompt systemPrompt: String?) async throws {
        createSessionCallCount += 1
        lastSystemPrompt = systemPrompt

        if let error = shouldThrowOnCreateSession {
            throw error
        }
    }

    func setEmailContext(_ email: Email?) {
        lastEmailContext = email
    }

    func clearConversation() {
        messages.removeAll()
        currentStreamText = ""
        lastResponseType = .none
    }

    func sendMessage(_ content: String) async throws -> String {
        sendMessageCallCount += 1
        lastReceivedMessage = content

        if let error = shouldThrowOnSendMessage {
            throw error
        }

        // Add user message
        let userMessage = AIService.Message(role: .user, content: content)
        messages.append(userMessage)

        // Add assistant response
        let assistantMessage = AIService.Message(role: .assistant, content: mockResponse)
        messages.append(assistantMessage)

        return mockResponse
    }

    func sendMessageStreaming(_ content: String, responseType: AIService.ResponseType) async throws -> AsyncThrowingStream<String, Error> {
        sendMessageStreamingCallCount += 1
        lastReceivedMessage = content

        if let error = shouldThrowOnSendMessage {
            throw error
        }

        // Add user message
        let userMessage = AIService.Message(role: .user, content: content)
        messages.append(userMessage)

        isGenerating = true
        currentStreamText = ""

        let response = mockResponse
        let delay = streamingDelay

        return AsyncThrowingStream { [weak self] continuation in
            Task { @MainActor [weak self] in
                let words = response.split(separator: " ")
                var accumulated = ""

                for word in words {
                    accumulated += (accumulated.isEmpty ? "" : " ") + word
                    self?.currentStreamText = accumulated
                    continuation.yield(accumulated)
                    try? await Task.sleep(nanoseconds: delay)
                }

                let assistantMessage = AIService.Message(role: .assistant, content: response)
                self?.messages.append(assistantMessage)
                self?.isGenerating = false
                self?.lastResponseType = responseType

                continuation.finish()
            }
        }
    }

    func summarizeEmail(_ email: Email) async throws -> String {
        summarizeEmailCallCount += 1
        lastEmailContext = email

        if let error = shouldThrowOnSummarize {
            throw error
        }

        lastResponseType = .summary
        return mockSummary
    }

    func generateReply(to email: Email, tone: String) async throws -> String {
        generateReplyCallCount += 1
        lastEmailContext = email
        lastReplyTone = tone

        if let error = shouldThrowOnGenerateReply {
            throw error
        }

        lastResponseType = .draftReply
        return mockReply
    }

    func improveWriting(_ text: String, instruction: String) async throws -> String {
        improveWritingCallCount += 1
        lastImproveWritingText = text
        lastImproveWritingInstruction = instruction

        if let error = shouldThrowOnImproveWriting {
            throw error
        }

        return mockImprovedWriting
    }

    func extractActionItems(from email: Email) async throws -> String {
        extractActionItemsCallCount += 1
        lastEmailContext = email

        if let error = shouldThrowOnExtractActionItems {
            throw error
        }

        lastResponseType = .actionItems
        return mockActionItems
    }

    func analyzeSentiment(of email: Email) async throws -> String {
        analyzeSentimentCallCount += 1
        lastEmailContext = email

        if let error = shouldThrowOnAnalyzeSentiment {
            throw error
        }

        return mockSentiment
    }

    // MARK: - Test Helpers

    /// Reset all state
    func reset() {
        isAvailable = true
        isGenerating = false
        currentStreamText = ""
        messages = []
        lastResponseType = .none

        mockResponse = "This is a mock AI response."
        mockSummary = "This email discusses important matters that require attention."
        mockReply = "Thank you for your email. I will review this and get back to you shortly."
        mockImprovedWriting = "Improved version of the text."
        mockActionItems = "- Review the attached document\n- Schedule follow-up meeting\n- Send confirmation email"
        mockSentiment = "The email has a professional and neutral tone."

        checkAvailabilityCallCount = 0
        createSessionCallCount = 0
        sendMessageCallCount = 0
        sendMessageStreamingCallCount = 0
        summarizeEmailCallCount = 0
        generateReplyCallCount = 0
        improveWritingCallCount = 0
        extractActionItemsCallCount = 0
        analyzeSentimentCallCount = 0

        lastReceivedMessage = nil
        lastEmailContext = nil
        lastSystemPrompt = nil
        lastImproveWritingText = nil
        lastImproveWritingInstruction = nil
        lastReplyTone = nil

        shouldThrowOnCreateSession = nil
        shouldThrowOnSendMessage = nil
        shouldThrowOnSummarize = nil
        shouldThrowOnGenerateReply = nil
        shouldThrowOnImproveWriting = nil
        shouldThrowOnExtractActionItems = nil
        shouldThrowOnAnalyzeSentiment = nil
    }

    /// Simulate unavailable AI
    func simulateUnavailable() {
        isAvailable = false
    }

    /// Simulate generating state
    func simulateGenerating(_ generating: Bool) {
        isGenerating = generating
    }

    /// Add a message to history
    func addMessage(role: AIService.Message.Role, content: String) {
        let message = AIService.Message(role: role, content: content)
        messages.append(message)
    }

    /// Get user messages only
    var userMessages: [AIService.Message] {
        messages.filter { $0.role == .user }
    }

    /// Get assistant messages only
    var assistantMessages: [AIService.Message] {
        messages.filter { $0.role == .assistant }
    }
}
