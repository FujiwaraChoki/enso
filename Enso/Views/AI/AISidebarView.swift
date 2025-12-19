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
        GlassEffectContainer {
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

                            // Contextual action chips
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
                                .padding(.top, 4)
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

                // Input area
                inputView
            }
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
            // Animated sparkle icon
            AISparkleIcon(isActive: aiService.isGenerating)

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Assistant")
                    .font(.headline)

                // Availability status
                HStack(spacing: 5) {
                    Circle()
                        .fill(aiService.isAvailable ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(aiService.isAvailable ? "Ready" : "Unavailable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Clear conversation button
            if !aiService.messages.isEmpty {
                Button(action: {
                    withAnimation(.spring(duration: 0.3)) {
                        aiService.clearConversation()
                        errorMessage = nil
                    }
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.glass)
                .help("Clear conversation")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            .regularMaterial,
            in: UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 0, bottomLeading: 12, bottomTrailing: 12, topTrailing: 0),
                style: .continuous
            )
        )
    }

    // MARK: - Email Context Card

    private func emailContextCard(_ email: Email) -> some View {
        HStack(spacing: 12) {
            // Email icon
            ZStack {
                Circle()
                    .fill(.blue.gradient.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: "envelope.fill")
                    .foregroundStyle(Color.blue)
                    .font(.system(size: 13))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Email Context")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(email.subject)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            Spacer()

            // Context indicator
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Icon with animated gradient
            ZStack {
                Circle()
                    .fill(
                        email == nil
                            ? AnyShapeStyle(.secondary.opacity(0.1))
                            : AnyShapeStyle(.blue.gradient.opacity(0.15))
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: email == nil ? "envelope.open" : "sparkles")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(email == nil ? Color.secondary : Color.blue)
            }
            .background(.regularMaterial, in: Circle())

            VStack(spacing: 10) {
                Text(email == nil ? "Select an Email" : "Ask Me Anything")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(email == nil
                     ? "Choose an email to get AI assistance"
                     : "I can summarize, draft replies, extract info, or answer questions about this email.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 24)

            // Quick action hints when email is selected
            if email != nil {
                HStack(spacing: 8) {
                    QuickHintPill(icon: "doc.text", text: "Summarize")
                    QuickHintPill(icon: "arrowshape.turn.up.left", text: "Reply")
                    QuickHintPill(icon: "checklist", text: "Tasks")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 12))
            }

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
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
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
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
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
                ZStack {
                    Circle()
                        .fill(sendButtonColor.gradient)
                        .frame(width: 36, height: 36)

                    Image(systemName: aiService.isGenerating ? "stop.fill" : "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .background(.regularMaterial, in: Circle())
            .disabled(inputText.isEmpty && !aiService.isGenerating)
            .opacity(inputText.isEmpty && !aiService.isGenerating ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            .regularMaterial,
            in: UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 16, bottomLeading: 0, bottomTrailing: 0, topTrailing: 16),
                style: .continuous
            )
        )
    }

    private var sendButtonColor: Color {
        if aiService.isGenerating {
            return .red
        } else if inputText.isEmpty {
            return .secondary
        } else {
            return .blue
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

/// Animated AI sparkle icon with glass effect
struct AISparkleIcon: View {
    let isActive: Bool

    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer glow when active
            if isActive {
                Circle()
                    .fill(.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .blur(radius: 4)
            }

            // Icon container
            ZStack {
                Circle()
                    .fill(.blue.gradient.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.blue)
                    .rotationEffect(.degrees(isActive ? rotation : 0))
                    .scaleEffect(isActive ? scale : 1.0)
            }
        .background(.regularMaterial, in: Circle())
        }
        .onChange(of: isActive) { _, active in
            if active {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    scale = 1.1
                }
            } else {
                rotation = 0
                scale = 1.0
            }
        }
    }
}

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
