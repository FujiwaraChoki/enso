//
//  AIFeaturesIntroView.swift
//  Enso
//

import SwiftUI

struct AIFeaturesIntroView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var showContent = false
    @State private var currentExample = 0

    private let examples = [
        ("sparkles", "Show me emails from Sarah"),
        ("doc.text", "Summarize this thread"),
        ("pencil.line", "Write a polite follow-up")
    ]

    private let features = [
        ("square.and.pencil", "Compose", "AI-assisted email writing"),
        ("doc.text.magnifyingglass", "Summarize", "Get the gist instantly"),
        ("magnifyingglass", "Search", "Find emails naturally")
    ]

    var body: some View {
        VStack(spacing: 32) {
            // Step indicator
            StepIndicator(currentStep: 3, totalSteps: 4)
                .opacity(showContent ? 1 : 0)

            // Header
            VStack(spacing: 8) {
                Text("Meet Your AI Assistant")
                    .font(.ensoTitle)
                    .foregroundStyle(.primary)

                Text("Powered by Apple Intelligence")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            Spacer()
                .frame(height: 20)

            // Animated examples panel
            VStack(spacing: 16) {
                ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                    AIExampleRow(
                        icon: example.0,
                        text: example.1,
                        isHighlighted: currentExample == index
                    )
                    .opacity(showContent ? 1 : 0)
                    .offset(x: showContent ? 0 : -30)
                    .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.15 + 0.3), value: showContent)
                }
            }
            .padding(24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 400)

            // Feature chips (static)
            HStack(spacing: 12) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    FeatureChip(
                        icon: feature.0,
                        title: feature.1,
                        description: feature.2
                    )
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.1 + 0.6), value: showContent)
                }
            }

            Spacer()

            // Privacy note
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.green)
                Text("Your AI assistant runs entirely on-device. Private by design.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: Capsule())
            .opacity(showContent ? 1 : 0)

            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    onboardingManager.goToPreviousStep()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.glass)

                Spacer()

                Button(action: {
                    onboardingManager.goToNextStep()
                }) {
                    HStack {
                        Text("Let's Go")
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.glass)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(40)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
        }
        .task {
            // Animate examples with proper cancellation
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentExample = (currentExample + 1) % examples.count
                }
            }
        }
    }
}

struct AIExampleRow: View {
    let icon: String
    let text: String
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isHighlighted ? Color.accentColor : Color.secondary.opacity(0.5))
                .frame(width: 24)

            Text("\"\(text)\"")
                .font(.body)
                .foregroundStyle(isHighlighted ? .primary : .secondary)
                .italic()

            Spacer()

            if isHighlighted {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.background.opacity(0.5))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
    }
}

struct FeatureChip: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 120, height: 100)
        .padding(.vertical, 16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ZStack {
        AnimatedGradientBackground()
        AIFeaturesIntroView()
    }
    .environmentObject(OnboardingManager())
}
