//
//  AIService.swift
//  Enso
//

import Foundation
import SwiftUI
import FoundationModels

/// Service for AI-powered email operations using Apple's Foundation Models
@MainActor
@Observable
final class AIService {

    // MARK: - Types

    enum AIError: LocalizedError {
        case sessionNotAvailable
        case generationFailed(Error)
        case toolExecutionFailed(String)
        case modelNotSupported
        case unsupportedLanguage

        var errorDescription: String? {
            switch self {
            case .sessionNotAvailable:
                return "AI session is not available on this device"
            case .generationFailed(let error):
                // Check for locale/language errors from Foundation Models
                let errorString = error.localizedDescription.lowercased()
                if errorString.contains("unsupported language") || errorString.contains("locale") {
                    return "Apple's on-device AI currently only supports English. The email may contain unsupported characters or language."
                }
                return "Generation failed: \(error.localizedDescription)"
            case .toolExecutionFailed(let reason):
                return "Tool execution failed: \(reason)"
            case .modelNotSupported:
                return "The AI model is not supported on this device"
            case .unsupportedLanguage:
                return "Apple's on-device AI currently only supports English. The email may contain unsupported characters or language."
            }
        }
    }

    struct Message: Identifiable, Equatable {
        let id: UUID
        let role: Role
        var content: String
        let timestamp: Date

        enum Role: Equatable {
            case user
            case assistant
            case system
        }

        init(role: Role, content: String) {
            self.id = UUID()
            self.role = role
            self.content = content
            self.timestamp = Date()
        }
    }

    // MARK: - Response Type (for contextual chips)

    enum ResponseType: Equatable {
        case none
        case summary
        case draftReply
        case extractedInfo
        case actionItems
        case other
    }

    // MARK: - Properties

    private(set) var isAvailable: Bool = false
    private(set) var isGenerating: Bool = false
    private(set) var currentStreamText: String = ""
    private(set) var messages: [Message] = []
    private(set) var lastResponseType: ResponseType = .none

    private var session: LanguageModelSession?
    private var emailContext: Email?

    // MARK: - Initialization

    init() {
        Task {
            await checkAvailability()
        }
    }

    // MARK: - Session Management

    /// Check if Foundation Models are available
    func checkAvailability() async {
        // Check if the system language model is available
        let availability = SystemLanguageModel.default.availability
        isAvailable = availability == .available
    }

    /// Create a new session with optional system prompt
    func createSession(withSystemPrompt systemPrompt: String? = nil) async throws {
        guard isAvailable else {
            throw AIError.sessionNotAvailable
        }

        let prompt = systemPrompt ?? defaultSystemPrompt

        session = LanguageModelSession(instructions: prompt)
    }

    /// Set email context for contextual assistance
    func setEmailContext(_ email: Email?) {
        emailContext = email
    }

    /// Clear conversation history
    func clearConversation() {
        messages.removeAll()
        currentStreamText = ""
        lastResponseType = .none
    }

    // MARK: - Generation

    /// Send a message and get a response
    func sendMessage(_ content: String) async throws -> String {
        guard let session = session else {
            try await createSession()
            return try await sendMessage(content)
        }

        // Add user message
        let userMessage = Message(role: .user, content: content)
        messages.append(userMessage)

        isGenerating = true
        currentStreamText = ""

        do {
            // Build the prompt with context if available
            let fullPrompt = buildPromptWithContext(content)

            // Generate response
            let response = try await session.respond(to: fullPrompt)
            let responseText = response.content

            let assistantMessage = Message(role: .assistant, content: responseText)
            messages.append(assistantMessage)

            isGenerating = false
            return responseText

        } catch {
            isGenerating = false
            throw AIError.generationFailed(error)
        }
    }

    /// Send a message with streaming response
    func sendMessageStreaming(_ content: String, responseType: ResponseType = .other) async throws -> AsyncThrowingStream<String, Error> {
        guard let session = session else {
            try await createSession()
            return try await sendMessageStreaming(content, responseType: responseType)
        }

        // Add user message
        let userMessage = Message(role: .user, content: content)
        messages.append(userMessage)

        isGenerating = true
        currentStreamText = ""

        let fullPrompt = buildPromptWithContext(content)
        let capturedResponseType = responseType

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = session.streamResponse(to: fullPrompt)

                    var fullResponse = ""
                    for try await partial in stream {
                        fullResponse = partial.content
                        await MainActor.run {
                            self.currentStreamText = fullResponse
                        }
                        continuation.yield(fullResponse)
                    }

                    await MainActor.run {
                        let assistantMessage = Message(role: .assistant, content: fullResponse)
                        self.messages.append(assistantMessage)
                        self.isGenerating = false
                        self.lastResponseType = capturedResponseType
                    }

                    continuation.finish()

                } catch {
                    await MainActor.run {
                        self.isGenerating = false
                    }
                    continuation.finish(throwing: AIError.generationFailed(error))
                }
            }
        }
    }

    // MARK: - Email-Specific Operations

    /// Summarize an email
    func summarizeEmail(_ email: Email) async throws -> String {
        let content = email.plainTextContent ?? "No content available"

        let prompt = """
        Please summarize this email concisely:

        From: \(email.senderDisplayName) <\(email.fromAddress)>
        Subject: \(email.subject)
        Date: \(email.date.formatted())

        \(content)

        Provide a 2-3 sentence summary of the key points.
        """

        let result = try await sendMessage(prompt)
        lastResponseType = .summary
        return result
    }

    /// Generate a reply draft
    func generateReply(to email: Email, tone: String = "professional") async throws -> String {
        let content = email.plainTextContent ?? "No content available"

        let prompt = """
        Generate a reply to this email with a \(tone) tone:

        From: \(email.senderDisplayName) <\(email.fromAddress)>
        Subject: \(email.subject)

        \(content)

        Write a concise, appropriate reply.
        """

        let result = try await sendMessage(prompt)
        lastResponseType = .draftReply
        return result
    }

    /// Improve writing in an email draft
    func improveWriting(_ text: String, instruction: String) async throws -> String {
        let prompt = """
        Please improve this email text with the following instruction: \(instruction)

        Original text:
        \(text)

        Provide the improved version only, without explanations.
        """

        return try await sendMessage(prompt)
    }

    /// Extract action items from email
    func extractActionItems(from email: Email) async throws -> String {
        let content = email.plainTextContent ?? "No content available"

        let prompt = """
        Extract any action items or tasks from this email:

        From: \(email.senderDisplayName)
        Subject: \(email.subject)

        \(content)

        List the action items as bullet points. If there are none, say "No action items found."
        """

        let result = try await sendMessage(prompt)
        lastResponseType = .actionItems
        return result
    }

    /// Analyze email sentiment
    func analyzeSentiment(of email: Email) async throws -> String {
        let content = email.plainTextContent ?? "No content available"

        let prompt = """
        Analyze the sentiment and tone of this email:

        From: \(email.senderDisplayName)
        Subject: \(email.subject)

        \(content)

        Describe the overall sentiment (positive, negative, neutral) and tone (formal, casual, urgent, etc.) in 1-2 sentences.
        """

        return try await sendMessage(prompt)
    }

    // MARK: - Private Helpers

    private var defaultSystemPrompt: String {
        """
        You are a helpful AI assistant integrated into an email application called Enso.
        Your role is to help users manage their emails efficiently by:
        - Summarizing emails and threads
        - Drafting replies and new emails
        - Extracting action items and important information
        - Improving email writing
        - Answering questions about email content

        Be concise, professional, and helpful. When drafting emails, match the appropriate tone for the context.
        Always respect user privacy - don't make assumptions about sensitive information.
        """
    }

    private func buildPromptWithContext(_ content: String) -> String {
        if let email = emailContext {
            return """
            [Context: Currently viewing email]
            From: \(email.senderDisplayName) <\(email.fromAddress)>
            Subject: \(email.subject)
            Date: \(email.date.formatted())
            Preview: \(email.previewText.prefix(200))

            User request: \(content)
            """
        }
        return content
    }
}

// MARK: - Environment Key

private struct AIServiceKey: EnvironmentKey {
    static let defaultValue: AIService = AIService()
}

extension EnvironmentValues {
    var aiService: AIService {
        get { self[AIServiceKey.self] }
        set { self[AIServiceKey.self] = newValue }
    }
}
