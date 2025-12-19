//
//  AITabView.swift
//  Enso
//

import SwiftUI
import SwiftData
import Combine

struct AITabView: View {
    let conversationId: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                Text("AI Assistant")
                    .font(.headline)

                Spacer()

                if aiService.isAvailable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Clear") {
                    aiService.clearConversation()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(aiService.messages.isEmpty)
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if aiService.messages.isEmpty && !aiService.isGenerating {
                            AIWelcomeView(onSuggestionTap: { suggestion in
                                inputText = suggestion
                                sendMessage()
                            })
                            .padding(.top, 40)
                        } else {
                            ForEach(aiService.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            // Streaming response
                            if aiService.isGenerating && !aiService.currentStreamText.isEmpty {
                                StreamingBubble(text: aiService.currentStreamText)
                                    .id("streaming")
                            } else if aiService.isGenerating {
                                ThinkingIndicator()
                                    .id("thinking")
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: aiService.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: aiService.currentStreamText) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            Divider()

            // Input area
            HStack(spacing: 12) {
                TextField("Ask about your emails...", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.background)
                            .stroke(.quaternary, lineWidth: 1)
                    }
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }
                    .disabled(!aiService.isAvailable || aiService.isGenerating)

                Button(action: sendMessage) {
                    Image(systemName: aiService.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(aiService.isGenerating ? .red : .blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty && !aiService.isGenerating)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .task {
            await aiService.checkAvailability()
            if aiService.isAvailable {
                try? await aiService.createSession()
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if aiService.isGenerating {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let lastMessage = aiService.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty, aiService.isAvailable else { return }

        let query = inputText
        inputText = ""

        Task {
            do {
                // Use streaming for better UX
                let stream = try await aiService.sendMessageStreaming(query)
                for try await _ in stream {
                    // Stream updates are handled by aiService.currentStreamText
                }
            } catch {
                print("AI Error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: AIService.Message

    var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isUser {
                Spacer(minLength: 60)
            } else {
                // AI avatar
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isUser ? Color.blue : Color(.controlBackgroundColor))
                    }
                    .foregroundStyle(isUser ? .white : .primary)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Streaming Bubble

struct StreamingBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // AI avatar
            Circle()
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.controlBackgroundColor))
                    }
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Generating...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 60)
        }
    }
}

// MARK: - Thinking Indicator

struct ThinkingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // AI avatar
            Circle()
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.white)
                }

            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Thinking" + String(repeating: ".", count: dotCount))
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .leading)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.controlBackgroundColor))
            }

            Spacer(minLength: 60)
        }
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}

// MARK: - Welcome View

struct AIWelcomeView: View {
    let onSuggestionTap: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("AI Email Assistant")
                    .font(.ensoTitle2)

                Text("I can help you search, summarize, and compose emails using natural language.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                SuggestionChip(text: "Show me unread emails from today", onTap: onSuggestionTap)
                SuggestionChip(text: "Summarize this thread", onTap: onSuggestionTap)
                SuggestionChip(text: "Draft a follow-up email", onTap: onSuggestionTap)
                SuggestionChip(text: "Find emails about project updates", onTap: onSuggestionTap)
            }
        }
        .frame(maxWidth: 400)
        .padding()
    }
}

struct SuggestionChip: View {
    let text: String
    let onTap: (String) -> Void

    var body: some View {
        Button(action: { onTap(text) }) {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(.background)
                        .stroke(.quaternary, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AITabView(conversationId: nil)
}
