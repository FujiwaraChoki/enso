//
//  SidebarMessageBubble.swift
//  Enso
//

import SwiftUI
import Combine

// MARK: - Sidebar User Bubble

/// A compact user message bubble optimized for the sidebar width.
/// Right-aligned with Liquid Glass effect.
struct SidebarUserBubble: View {
    let message: AIService.Message

    @State private var isHovered = false

    var body: some View {
        HStack {
            Spacer(minLength: 48)

            VStack(alignment: .trailing, spacing: 6) {
                Text(message.content)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        .blue.gradient,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .scaleEffect(isHovered ? 1.01 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: isHovered)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 4)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Sidebar Assistant Bubble

/// A compact assistant message bubble.
/// Left-aligned with Liquid Glass effect.
struct SidebarAssistantBubble: View {
    let message: AIService.Message

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(message.content)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .scaleEffect(isHovered ? 1.01 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: isHovered)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            }

            Spacer(minLength: 24)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Sidebar Streaming Bubble

/// A streaming response bubble with animated text and Liquid Glass.
struct SidebarStreamingBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                AnimatedStreamText(
                    text: text,
                    isStreaming: true,
                    font: .callout,
                    foregroundStyle: .primary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

                // Streaming indicator
                StreamingIndicator()
            }

            Spacer(minLength: 24)
        }
    }
}

// MARK: - Sidebar Thinking Bubble

/// A thinking indicator shown before the first streaming chunk arrives.
struct SidebarThinkingBubble: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HStack(spacing: 6) {
                ThinkingDots()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )

            Spacer(minLength: 24)
        }
    }
}

// MARK: - Streaming Indicator

/// Shows streaming status with animated dots
private struct StreamingIndicator: View {
    @State private var activeDot = 0
    let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 4, height: 4)
                        .opacity(activeDot == index ? 1.0 : 0.35)
                        .scaleEffect(activeDot == index ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: activeDot)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .onReceive(timer) { _ in
            activeDot = (activeDot + 1) % 3
        }
    }
}

/// Animated thinking dots with wave animation.
private struct ThinkingDots: View {
    @State private var animationPhase = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(scaleForDot(index))
                    .opacity(opacityForDot(index))
                    .animation(.spring(duration: 0.35), value: animationPhase)
            }
        }
        .onReceive(timer) { _ in
            animationPhase = (animationPhase + 1) % 3
        }
    }

    private func scaleForDot(_ index: Int) -> CGFloat {
        animationPhase == index ? 1.3 : 0.85
    }

    private func opacityForDot(_ index: Int) -> Double {
        animationPhase == index ? 1.0 : 0.5
    }
}

// MARK: - Message Bubble Factory

/// A view that automatically renders the appropriate bubble type based on message role.
struct SidebarMessageBubble: View {
    let message: AIService.Message

    var body: some View {
        switch message.role {
        case .user:
            SidebarUserBubble(message: message)
        case .assistant:
            SidebarAssistantBubble(message: message)
        case .system:
            // System messages are typically not displayed
            EmptyView()
        }
    }
}

// MARK: - Previews

#Preview("User Bubble") {
    SidebarUserBubble(message: .init(role: .user, content: "What's this email about?"))
        .padding()
        .frame(width: 350)
}

#Preview("Assistant Bubble") {
    SidebarAssistantBubble(message: .init(role: .assistant, content: "This email discusses the upcoming project deadline and requests an update on the current progress."))
        .padding()
        .frame(width: 350)
}

#Preview("Streaming Bubble") {
    SidebarStreamingBubble(text: "This email is about the quarterly report and discusses several key metrics including...")
        .padding()
        .frame(width: 350)
}

#Preview("Thinking Bubble") {
    SidebarThinkingBubble()
        .padding()
        .frame(width: 350)
}
