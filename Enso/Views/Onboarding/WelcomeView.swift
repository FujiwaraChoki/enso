//
//  WelcomeView.swift
//  Enso
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var showContent = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: 32) {
            // Step indicator
            StepIndicator(currentStep: 1, totalSteps: 4)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -10)

            Spacer()

            // App icon placeholder
            ZStack {
                Circle()
                    .frame(width: 120, height: 120)

                Image(systemName: "envelope.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
            }
            .glassEffect(.regular, in: Circle())
            .scaleEffect(showContent ? 1 : 0.8)
            .opacity(showContent ? 1 : 0)

            VStack(spacing: 16) {
                // Welcome title - Instrument Serif
                Text("Welcome to Enso")
                    .font(.ensoLargeTitle)
                    .foregroundStyle(.primary)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                // Subtitle - Instrument Serif Italic
                Text("Your mindful email companion")
                    .font(.ensoSubtitle)
                    .foregroundStyle(.secondary)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
            }

            Spacer()

            // Get Started button with Glass effect
            Button(action: {
                onboardingManager.goToNextStep()
            }) {
                HStack(spacing: 8) {
                    Text("Get Started")
                        .font(.headline)

                    Image(systemName: "arrow.right")
                        .font(.headline)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
            }
            .buttonStyle(.glass)
            .keyboardShortcut(.return, modifiers: .command)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)

            Spacer()
                .frame(height: 60)
        }
        .padding(40)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                showButton = true
            }
        }
    }
}

#Preview {
    ZStack {
        AnimatedGradientBackground()
        WelcomeView()
    }
    .environmentObject(OnboardingManager())
}
