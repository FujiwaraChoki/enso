//
//  OnboardingCompleteView.swift
//  Enso
//

import SwiftUI

struct OnboardingCompleteView: View {
    let onComplete: () -> Void

    @State private var showCheckmarks = false
    @State private var showButton = false
    @State private var syncProgress: Double = 0
    @State private var isSyncing = true

    private let checkItems = [
        ("checkmark.circle.fill", "Account connected"),
        ("sparkles", "AI assistant ready"),
        ("arrow.triangle.2.circlepath", "Syncing your inbox...")
    ]

    var body: some View {
        VStack(spacing: 40) {
            // Step indicator
            StepIndicator(currentStep: 4, totalSteps: 4)
                .opacity(showCheckmarks ? 1 : 0)

            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.green)
            }
            .glassEffect(.regular, in: Circle())
            .scaleEffect(showCheckmarks ? 1 : 0.5)
            .opacity(showCheckmarks ? 1 : 0)

            // Title
            Text("You're all set")
                .font(.ensoLargeTitle)
                .foregroundStyle(.primary)
                .opacity(showCheckmarks ? 1 : 0)
                .offset(y: showCheckmarks ? 0 : 20)

            // Checklist
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(checkItems.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.0)
                            .font(.title3)
                            .foregroundStyle(index == 2 && isSyncing ? .blue : .green)
                            .frame(width: 24)
                            .rotationEffect(index == 2 && isSyncing ? .degrees(360) : .zero)
                            .animation(
                                index == 2 && isSyncing ?
                                    .linear(duration: 1).repeatForever(autoreverses: false) :
                                    .default,
                                value: isSyncing
                            )

                        Text(item.1)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        if index < 2 {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        } else if isSyncing {
                            Text("\(Int(syncProgress))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .opacity(showCheckmarks ? 1 : 0)
                    .offset(x: showCheckmarks ? 0 : -20)
                    .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.2 + 0.3), value: showCheckmarks)
                }

                // Sync progress bar
                if isSyncing {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.quaternary)
                                .frame(height: 4)

                            Capsule()
                                .fill(.tint)
                                .frame(width: geometry.size.width * (syncProgress / 100), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 8)
                    .opacity(showCheckmarks ? 1 : 0)
                }
            }
            .padding(24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: 350)

            Spacer()

            // Open Enso button
            Button(action: onComplete) {
                HStack {
                    Text("Open Enso")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
            }
            .buttonStyle(.glass)
            .keyboardShortcut(.return, modifiers: .command)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
            .disabled(isSyncing && syncProgress < 100)

            Spacer()
                .frame(height: 40)
        }
        .padding(40)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showCheckmarks = true
            }

            // Simulate sync progress
            simulateSync()
        }
    }

    private func simulateSync() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if syncProgress < 100 {
                syncProgress += Double.random(in: 0.5...2.0)
                syncProgress = min(syncProgress, 100)
            } else {
                timer.invalidate()
                withAnimation(.easeOut(duration: 0.3)) {
                    isSyncing = false
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                    showButton = true
                }
            }
        }
    }
}

#Preview {
    ZStack {
        AnimatedGradientBackground()
        OnboardingCompleteView {
            print("Complete!")
        }
    }
}
