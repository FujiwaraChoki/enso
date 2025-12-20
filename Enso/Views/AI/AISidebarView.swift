//
//  AISidebarView.swift
//  Enso
//

import SwiftUI

struct AISidebarView: View {
    let email: Email?

    @Environment(\.aiService) private var aiService
    @EnvironmentObject private var tabManager: TabManager
    @State private var inputText = ""
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Email context card
            if let email = email {
                emailContextCard(email)
            }

            // Chat content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Empty state
                        if aiService.messages.isEmpty && !aiService.isGenerating {
                            emptyStateView
                        } else {
                            // Messages
                            ForEach(aiService.messages) { message in
                                SidebarMessageBubble(message: message)
                                    .id(message.id)
                            }

                            // Streaming response
                            if aiService.isGenerating {
                                if !aiService.currentStreamText.isEmpty {
                                    SidebarStreamingBubble(text: aiService.currentStreamText)
                                        .id("streaming")
                                } else {
                                    SidebarThinkingBubble()
                                        .id("thinking")
                                }
                            }

                            // Error state
                            if let error = errorMessage {
                                errorView(error)
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollClipDisabled()
                .onChange(of: aiService.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: aiService.currentStreamText) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            // Contextual action chips (Suggestions)
            if email != nil && !aiService.isGenerating {
                ContextualActionChips(
                    hasEmail: email != nil,
                    lastResponseType: aiService.lastResponseType,
                    isGenerating: aiService.isGenerating,
                    onChipTap: { chip in
                        Task {
                            await handleChipTap(chip)
                        }
                    },
                    onCopy: copyLastResponse
                )
                .padding(.bottom, 8)
            }

            // Input area
            inputView
        }
        .onChange(of: email) { _, newEmail in
            aiService.setEmailContext(newEmail)
            errorMessage = nil
        }
        .task {
            await aiService.checkAvailability()
            if aiService.isAvailable {
                try? await aiService.createSession()
            }
            aiService.setEmailContext(email)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            Text("Assistant")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundStyle(.primary)

            Spacer()

            // Availability status
            if !aiService.isAvailable {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("Unavailable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Clear conversation button
            if !aiService.messages.isEmpty {
                Button(action: {
                    withAnimation(.spring(duration: 0.3)) {
                        aiService.clearConversation()
                        errorMessage = nil
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .help("Clear conversation")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Email Context Card

    private func emailContextCard(_ email: Email) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))

            Text(email.subject)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.3))

            Text(email == nil ? "Select an email to start" : "How can I help with this email?")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))

            Text(error)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()

            Button("Dismiss") {
                withAnimation(.spring(duration: 0.2)) {
                    errorMessage = nil
                }
            }
            .font(.caption)
            .fontWeight(.semibold)
            .buttonStyle(.glass)
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Input View

    private var inputView: some View {
        HStack(spacing: 10) {
            // Text input field
            TextField("Ask anything...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: Capsule())
                .focused($isInputFocused)
                .onSubmit {
                    Task {
                        await sendMessage()
                    }
                }
                .disabled(!aiService.isAvailable || aiService.isGenerating)

            // Send/Stop button
            Button(action: {
                Task {
                    if aiService.isGenerating {
                        // Stop generation
                    } else {
                        await sendMessage()
                    }
                }
            }) {
                Image(systemName: aiService.isGenerating ? "stop.fill" : "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(sendButtonColor)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .disabled(inputText.isEmpty && !aiService.isGenerating)
            .opacity(inputText.isEmpty && !aiService.isGenerating ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private var sendButtonColor: Color {
        if aiService.isGenerating {
            return .red
        } else if inputText.isEmpty {
            return .secondary
        } else {
            return .primary
        }
    }

    // MARK: - Actions

    @MainActor
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if aiService.isGenerating {
                if !aiService.currentStreamText.isEmpty {
                    proxy.scrollTo("streaming", anchor: .bottom)
                } else {
                    proxy.scrollTo("thinking", anchor: .bottom)
                }
            } else if let lastMessage = aiService.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    @MainActor
    private func sendMessage() async {
        guard !inputText.isEmpty, aiService.isAvailable else { return }

        let query = inputText
        inputText = ""
        errorMessage = nil

        do {
            let stream = try await aiService.sendMessageStreaming(query, responseType: .other)
            for try await _ in stream {
                // Stream updates are handled by aiService.currentStreamText
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func handleChipTap(_ chip: ActionChip) async {
        guard email != nil else { return }
        errorMessage = nil

        // Determine the response type based on the chip
        let responseType: AIService.ResponseType
        switch chip {
        case .summarize:
            responseType = .summary
        case .draftReply:
            responseType = .draftReply
        case .extractInfo:
            responseType = .extractedInfo
        case .actionItems:
            responseType = .actionItems
        case .moreDetail, .makeShorter, .makeFormal, .makeCasual:
            responseType = .other
        case .copy:
            return // Copy is handled separately
        }

        do {
            // Build a contextual prompt based on the chip
            let prompt: String
            switch chip {
            case .summarize:
                prompt = "Please summarize this email concisely in 2-3 sentences."
            case .draftReply:
                prompt = "Draft a professional reply to this email."
            case .extractInfo:
                prompt = "Extract key information from this email including dates, names, topics, and any requests."
            case .actionItems:
                prompt = "List any action items or tasks mentioned in this email."
            case .moreDetail:
                prompt = "Please provide more detail about your previous response."
            case .makeShorter:
                prompt = "Please make the previous response shorter and more concise."
            case .makeFormal:
                prompt = "Please rewrite the previous response in a more formal, professional tone."
            case .makeCasual:
                prompt = "Please rewrite the previous response in a more casual, friendly tone."
            case .copy:
                return
            }

            let stream = try await aiService.sendMessageStreaming(prompt, responseType: responseType)
            for try await _ in stream {
                // Stream updates handled automatically
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func copyLastResponse() {
        guard let lastAssistantMessage = aiService.messages.last(where: { $0.role == .assistant }) else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastAssistantMessage.content, forType: .string)
    }
}

// MARK: - Supporting Components

/// Quick hint pill shown in empty state
struct QuickHintPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }
}

#Preview {
    AISidebarView(email: nil)
        .frame(width: 350)
}
