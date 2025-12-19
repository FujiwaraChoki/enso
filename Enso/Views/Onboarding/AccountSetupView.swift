//
//  AccountSetupView.swift
//  Enso
//

import SwiftUI

struct AccountSetupView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var showAdvanced = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password, imapHost, imapPort, smtpHost, smtpPort
    }

    var body: some View {
        VStack(spacing: 24) {
            // Step indicator
            StepIndicator(currentStep: 2, totalSteps: 4)

            // Header
            VStack(spacing: 8) {
                Text("Connect Your Email")
                    .font(.ensoTitle)
                    .foregroundStyle(.primary)

                Text("Enter your email credentials to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
                .frame(height: 20)

            // Form content
            VStack(spacing: 20) {
                // Email field
                GlassTextField(
                    title: "Email Address",
                    placeholder: "you@example.com",
                    text: $onboardingManager.emailAddress,
                    icon: "envelope"
                )
                .focused($focusedField, equals: .email)
                .textContentType(.emailAddress)
                .onChange(of: onboardingManager.emailAddress) { _, _ in
                    onboardingManager.autoDetectServerSettings()
                }

                // Password field
                GlassSecureField(
                    title: "Password",
                    placeholder: "Your email password",
                    text: $onboardingManager.password,
                    icon: "lock"
                )
                .focused($focusedField, equals: .password)

                // Advanced settings toggle
                DisclosureGroup(isExpanded: $showAdvanced) {
                    VStack(spacing: 16) {
                        // IMAP Settings
                        HStack(spacing: 12) {
                            GlassTextField(
                                title: "IMAP Server",
                                placeholder: "imap.example.com",
                                text: $onboardingManager.imapHost,
                                icon: "server.rack"
                            )
                            .focused($focusedField, equals: .imapHost)

                            GlassTextField(
                                title: "Port",
                                placeholder: "993",
                                text: $onboardingManager.imapPort,
                                icon: nil
                            )
                            .focused($focusedField, equals: .imapPort)
                            .frame(width: 100)
                        }

                        // SMTP Settings
                        HStack(spacing: 12) {
                            GlassTextField(
                                title: "SMTP Server",
                                placeholder: "smtp.example.com",
                                text: $onboardingManager.smtpHost,
                                icon: "paperplane"
                            )
                            .focused($focusedField, equals: .smtpHost)

                            GlassTextField(
                                title: "Port",
                                placeholder: "587",
                                text: $onboardingManager.smtpPort,
                                icon: nil
                            )
                            .focused($focusedField, equals: .smtpPort)
                            .frame(width: 100)
                        }

                        // TLS Toggle
                        Toggle(isOn: $onboardingManager.useTLS) {
                            Label("Use TLS/SSL", systemImage: "lock.shield")
                                .foregroundStyle(.secondary)
                        }
                        .toggleStyle(.switch)
                    }
                    .padding(.top, 12)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                        Text("Server Settings")
                        if !onboardingManager.imapHost.isEmpty {
                            Text("(auto-detected)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        HelpButton(
                            title: "About Server Settings",
                            message: "IMAP is used to receive emails, while SMTP is used to send them. Enso will try to detect these settings automatically based on your email address."
                        )
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .tint(.secondary)

                // Connection test result
                if let result = onboardingManager.connectionTestResult {
                    ConnectionResultBanner(result: result)
                }
            }
            .padding(24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

            Spacer()

            // Action buttons
            HStack(spacing: 16) {
                // Back button
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

                // Test Connection button
                Button(action: {
                    Task {
                        await onboardingManager.testConnection()
                    }
                }) {
                    HStack {
                        if onboardingManager.isTestingConnection {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "network")
                        }
                        Text("Test Connection")
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.glass)
                .disabled(onboardingManager.emailAddress.isEmpty || onboardingManager.password.isEmpty)

                // Continue button
                Button(action: {
                    onboardingManager.goToNextStep()
                }) {
                    HStack {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.glass)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!onboardingManager.isAccountSetupValid)
            }
        }
        .padding(40)
        .frame(maxWidth: 600)
    }
}

// MARK: - Connection Result Banner

struct ConnectionResultBanner: View {
    let result: OnboardingManager.ConnectionTestResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.isSuccess ? .green : .red)
                .imageScale(.medium)

            Text(result.isSuccess ? "Connection successful!" : {
                if case .failure(let message) = result {
                    return message
                }
                return "Connection failed"
            }())
            .font(.subheadline)
            .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(result.isSuccess ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ZStack {
        AnimatedGradientBackground()
        AccountSetupView()
    }
    .environmentObject(OnboardingManager())
}
