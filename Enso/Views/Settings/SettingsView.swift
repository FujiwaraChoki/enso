//
//  SettingsView.swift
//  Enso
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AccountSettingsView()
                .tabItem {
                    Label("Accounts", systemImage: "person.2")
                }

            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage("tabBehavior") private var tabBehavior: String = TabBehavior.splitPaneWithTabs.rawValue
    @AppStorage("showConfettiOnSend") private var showConfettiOnSend: Bool = true

    var body: some View {
        Form {
            Section("Tab Behavior") {
                Picker("When opening content:", selection: $tabBehavior) {
                    ForEach(TabBehavior.allCases, id: \.rawValue) { behavior in
                        VStack(alignment: .leading) {
                            Text(behavior.displayName)
                            Text(behavior.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(behavior.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Appearance") {
                Toggle("Show unread count in dock", isOn: .constant(true))
                Toggle("Show notifications for new emails", isOn: .constant(true))
                Toggle("Celebrate with confetti when sending email", isOn: $showConfettiOnSend)
            }

            Section("Sync") {
                Picker("Check for new emails:", selection: .constant("5min")) {
                    Text("Every minute").tag("1min")
                    Text("Every 5 minutes").tag("5min")
                    Text("Every 15 minutes").tag("15min")
                    Text("Manually").tag("manual")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Account Settings

struct AccountSettingsView: View {
    @Query private var accounts: [Account]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddAccount = false

    var body: some View {
        VStack(spacing: 0) {
            if accounts.isEmpty {
                ContentUnavailableView(
                    "No Accounts",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("Add an email account to get started")
                )
            } else {
                List {
                    ForEach(accounts) { account in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(account.name)
                                    .font(.headline)
                                Text(account.emailAddress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Circle()
                                .fill(account.syncStatus == .connected ? .green : .orange)
                                .frame(width: 8, height: 8)

                            Text(account.syncStatus.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteAccounts)
                }
            }

            Divider()

            HStack {
                Button("Add Account...") {
                    showAddAccount = true
                }
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountSheet()
        }
    }

    private func deleteAccounts(at offsets: IndexSet) {
        for index in offsets {
            let account = accounts[index]
            // Delete credentials from Keychain
            Task {
                try? await KeychainService.shared.deleteCredentials(for: account)
            }
            modelContext.delete(account)
        }
    }
}

struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var email = ""
    @State private var password = ""
    @State private var imapHost = ""
    @State private var smtpHost = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Email Account")
                .font(.headline)

            Form {
                TextField("Email Address", text: $email)
                SecureField("Password", text: $password)
                TextField("IMAP Server", text: $imapHost)
                TextField("SMTP Server", text: $smtpHost)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add") {
                    addAccount()
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func addAccount() {
        let account = Account(
            name: email.components(separatedBy: "@").first ?? email,
            emailAddress: email,
            imapHost: imapHost,
            smtpHost: smtpHost
        )
        modelContext.insert(account)

        Task {
            try? await KeychainService.shared.saveCredentials(for: account, password: password)
        }

        dismiss()
    }
}

// MARK: - AI Settings

struct AISettingsView: View {
    @State private var aiEnabled = true
    @State private var autoSummarize = true
    @State private var smartCompose = true

    var body: some View {
        Form {
            Section("AI Features") {
                Toggle("Enable AI Assistant", isOn: $aiEnabled)

                if aiEnabled {
                    Toggle("Auto-summarize long emails", isOn: $autoSummarize)
                    Toggle("Smart compose suggestions", isOn: $smartCompose)
                }
            }

            Section {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("Privacy")
                            .font(.headline)
                        Text("All AI processing happens on-device using Apple Intelligence. Your emails never leave your Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Account.self)
}
