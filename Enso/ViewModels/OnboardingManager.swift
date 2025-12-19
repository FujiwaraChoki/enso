//
//  OnboardingManager.swift
//  Enso
//

import SwiftUI
import Combine

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case accountSetup
    case aiIntro
    case complete

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .accountSetup: return "Connect Your Email"
        case .aiIntro: return "Meet Your AI Assistant"
        case .complete: return "You're All Set"
        }
    }

    var canGoBack: Bool {
        self != .welcome && self != .complete
    }

    var nextStep: OnboardingStep? {
        guard let nextIndex = OnboardingStep.allCases.firstIndex(of: self)?.advanced(by: 1),
              nextIndex < OnboardingStep.allCases.count else {
            return nil
        }
        return OnboardingStep.allCases[nextIndex]
    }

    var previousStep: OnboardingStep? {
        guard let prevIndex = OnboardingStep.allCases.firstIndex(of: self)?.advanced(by: -1),
              prevIndex >= 0 else {
            return nil
        }
        return OnboardingStep.allCases[prevIndex]
    }
}

class OnboardingManager: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isTransitioning = false

    // Account setup state
    @Published var emailAddress = ""
    @Published var password = ""
    @Published var imapHost = ""
    @Published var imapPort = "993"
    @Published var smtpHost = ""
    @Published var smtpPort = "587"
    @Published var useTLS = true

    // Connection state
    @Published var isTestingConnection = false
    @Published var connectionTestResult: ConnectionTestResult?

    enum ConnectionTestResult {
        case success
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    // MARK: - Navigation

    func goToNextStep() {
        guard let next = currentStep.nextStep else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            isTransitioning = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.currentStep = next
                self.isTransitioning = false
            }
        }
    }

    func goToPreviousStep() {
        guard let prev = currentStep.previousStep else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            isTransitioning = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.currentStep = prev
                self.isTransitioning = false
            }
        }
    }

    // MARK: - Account Setup

    func autoDetectServerSettings() {
        guard !emailAddress.isEmpty else { return }

        let domain = emailAddress.components(separatedBy: "@").last ?? ""

        // Common provider detection
        switch domain.lowercased() {
        case "icloud.com", "me.com", "mac.com":
            imapHost = "imap.mail.me.com"
            smtpHost = "smtp.mail.me.com"
        case "outlook.com", "hotmail.com", "live.com":
            imapHost = "outlook.office365.com"
            smtpHost = "smtp.office365.com"
        case "yahoo.com":
            imapHost = "imap.mail.yahoo.com"
            smtpHost = "smtp.mail.yahoo.com"
        case "protonmail.com", "proton.me":
            // ProtonMail requires Bridge
            imapHost = "127.0.0.1"
            smtpHost = "127.0.0.1"
            imapPort = "1143"
            smtpPort = "1025"
        default:
            // Generic guess
            imapHost = "imap.\(domain)"
            smtpHost = "smtp.\(domain)"
        }
    }

    func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil

        // Simulate connection test for now
        // In production, this would actually test IMAP/SMTP connection
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // For demo purposes, succeed if fields are filled
        if !emailAddress.isEmpty && !password.isEmpty && !imapHost.isEmpty && !smtpHost.isEmpty {
            connectionTestResult = .success
        } else {
            connectionTestResult = .failure("Please fill in all required fields")
        }

        isTestingConnection = false
    }

    func createAccount() -> Account {
        Account(
            name: emailAddress.components(separatedBy: "@").first ?? emailAddress,
            emailAddress: emailAddress,
            imapHost: imapHost,
            imapPort: Int(imapPort) ?? 993,
            imapUseTLS: useTLS,
            smtpHost: smtpHost,
            smtpPort: Int(smtpPort) ?? 587,
            smtpUseTLS: useTLS
        )
    }

    var isAccountSetupValid: Bool {
        !emailAddress.isEmpty &&
        !password.isEmpty &&
        !imapHost.isEmpty &&
        !smtpHost.isEmpty &&
        connectionTestResult?.isSuccess == true
    }

    // MARK: - Progress

    var progress: Double {
        Double(currentStep.rawValue) / Double(OnboardingStep.allCases.count - 1)
    }
}
