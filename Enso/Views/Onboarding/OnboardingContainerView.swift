//
//  OnboardingContainerView.swift
//  Enso
//

import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            // Animated background gradient
            AnimatedGradientBackground()

            VStack(spacing: 0) {
                // Progress indicator (hidden on welcome)
                if onboardingManager.currentStep != .welcome {
                    OnboardingProgressBar(progress: onboardingManager.progress)
                        .padding(.top, 20)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                }

                Spacer()

                // Step content
                Group {
                    switch onboardingManager.currentStep {
                    case .welcome:
                        WelcomeView()
                    case .accountSetup:
                        AccountSetupView()
                    case .aiIntro:
                        AIFeaturesIntroView()
                    case .complete:
                        OnboardingCompleteView {
                            completeOnboarding()
                        }
                    }
                }
                .opacity(onboardingManager.isTransitioning ? 0 : 1)
                .offset(y: onboardingManager.isTransitioning ? 20 : 0)

                Spacer()
            }
        }
        .frame(minWidth: 700, minHeight: 550)
        .frame(maxWidth: 900, maxHeight: 700)
    }

    private func completeOnboarding() {
        // Save account to database
        let account = onboardingManager.createAccount()
        modelContext.insert(account)

        // Save password to Keychain
        Task {
            try? await KeychainService.shared.saveCredentials(
                for: account,
                password: onboardingManager.password
            )
        }

        // Complete onboarding
        withAnimation(.easeInOut(duration: 0.5)) {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Progress Bar

struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 4)

                // Progress fill
                Capsule()
                    .fill(.tint)
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Animated Background

struct AnimatedGradientBackground: View {
    var body: some View {
        Color(.windowBackgroundColor)
            .ignoresSafeArea()
    }
}

#Preview {
    OnboardingContainerView()
        .environmentObject(OnboardingManager())
}
