//
//  AIServiceProtocol.swift
//  EnsoTests
//

import Foundation
@testable import Enso

/// Protocol for AIService to enable testing with mocks
@MainActor
protocol AIServiceProtocol {
    /// Whether AI is available on this device
    var isAvailable: Bool { get }

    /// Whether the service is currently generating a response
    var isGenerating: Bool { get }

    /// Current streaming response text
    var currentStreamText: String { get }

    /// Conversation message history
    var messages: [AIService.Message] { get }

    /// Last response type for contextual UI
    var lastResponseType: AIService.ResponseType { get }

    /// Check if Foundation Models are available
    func checkAvailability() async

    /// Create a new session with optional system prompt
    func createSession(withSystemPrompt systemPrompt: String?) async throws

    /// Set email context for contextual assistance
    func setEmailContext(_ email: Email?)

    /// Clear conversation history
    func clearConversation()

    /// Send a message and get a response
    func sendMessage(_ content: String) async throws -> String

    /// Send a message with streaming response
    func sendMessageStreaming(_ content: String, responseType: AIService.ResponseType) async throws -> AsyncThrowingStream<String, Error>

    /// Summarize an email
    func summarizeEmail(_ email: Email) async throws -> String

    /// Generate a reply draft
    func generateReply(to email: Email, tone: String) async throws -> String

    /// Improve writing in an email draft
    func improveWriting(_ text: String, instruction: String) async throws -> String

    /// Extract action items from email
    func extractActionItems(from email: Email) async throws -> String

    /// Analyze email sentiment
    func analyzeSentiment(of email: Email) async throws -> String
}
