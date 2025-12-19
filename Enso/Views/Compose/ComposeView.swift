//
//  ComposeView.swift
//  Enso
//

import SwiftUI
import SwiftData
import ConfettiSwiftUI

struct ComposeView: View {
    let draftId: UUID?

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var tabManager: TabManager
    @Query private var accounts: [Account]

    @AppStorage("showConfettiOnSend") private var showConfettiOnSend: Bool = true

    @State private var to = ""
    @State private var cc = ""
    @State private var bcc = ""
    @State private var subject = ""
    @State private var emailBody = ""
    @State private var showCcBcc = false
    @State private var showAIAssistant = false
    @State private var isSending = false
    @State private var sendError: String?
    @State private var selectedAccountId: UUID?
    @State private var confettiCounter = 0

    @FocusState private var focusedField: ComposeField?

    private enum ComposeField: Hashable {
        case to, cc, bcc, subject, body
    }

    private var replyContext: ReplyContext? {
        tabManager.currentReplyContext
    }

    private var activeAccount: Account? {
        if let id = selectedAccountId {
            return accounts.first { $0.id == id }
        }
        return accounts.first { $0.isActive }
    }

    private var canSend: Bool {
        !to.isEmpty && !subject.isEmpty && !isSending && activeAccount != nil
    }

    var body: some View {
        HStack(spacing: 0) {
            // Main compose area
            VStack(spacing: 0) {
                // Header fields
                VStack(spacing: 0) {
                    // From row
                    if accounts.count > 0 {
                        ComposeFieldRow(label: "From") {
                            if accounts.count > 1 {
                                Menu {
                                    ForEach(accounts) { account in
                                        Button(account.emailAddress) {
                                            selectedAccountId = account.id
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(activeAccount?.emailAddress ?? "Select")
                                            .foregroundStyle(.primary)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(activeAccount?.emailAddress ?? "")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }

                    // To row
                    ComposeFieldRow(label: "To") {
                        TextField("Recipients", text: $to)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .to)

                        if !showCcBcc {
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    showCcBcc = true
                                }
                            } label: {
                                Text("Cc Bcc")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Cc/Bcc rows
                    if showCcBcc {
                        ComposeFieldRow(label: "Cc") {
                            TextField("", text: $cc)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .cc)
                        }

                        ComposeFieldRow(label: "Bcc") {
                            TextField("", text: $bcc)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .bcc)
                        }
                    }

                    // Subject row
                    ComposeFieldRow(label: "Subject", showDivider: false) {
                        TextField("", text: $subject)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .subject)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Divider()
                    .padding(.horizontal, 20)

                // Body
                ZStack(alignment: .topLeading) {
                    if emailBody.isEmpty {
                        Text("Write your message...")
                            .foregroundStyle(.quaternary)
                            .padding(.top, 12)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $emailBody)
                        .scrollContentBackground(.hidden)
                        .focused($focusedField, equals: .body)
                        .padding(.top, 4)
                }
                .font(.body)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(maxHeight: .infinity)

                // Bottom bar
                HStack(spacing: 8) {
                    // Attach
                    ToolbarButton(icon: "paperclip", label: "Attach") {}

                    // AI
                    ToolbarButton(
                        icon: "sparkles",
                        label: "AI",
                        isActive: showAIAssistant
                    ) {
                        showAIAssistant.toggle()
                    }

                    Spacer()

                    // Error
                    if let error = sendError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }

                    // Discard
                    Button {
                        tabManager.currentReplyContext = nil
                        if let currentTab = tabManager.currentTab {
                            tabManager.closeTab(currentTab.id)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .help("Discard")

                    // Send
                    Button {
                        Task { await sendEmail() }
                    } label: {
                        HStack(spacing: 6) {
                            if isSending {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 12))
                            }
                            Text(isSending ? "Sending" : "Send")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            canSend ? Color.accentColor : Color.secondary.opacity(0.5),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .keyboardShortcut(.return, modifiers: .command)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .frame(minWidth: 480)

            // AI Panel
            if showAIAssistant {
                Divider()

                ComposeAIPanel(
                    emailBody: $emailBody,
                    subject: subject,
                    onDismiss: { showAIAssistant = false }
                )
                .frame(width: 300)
            }
        }
        .background(.background)
        .navigationTitle(navigationTitle)
        .onAppear {
            setupFromReplyContext()
            focusedField = .to
        }
        .alert("Send Error", isPresented: .constant(sendError != nil)) {
            Button("OK") { sendError = nil }
        } message: {
            if let error = sendError {
                Text(error)
            }
        }
        .confettiCannon(trigger: $confettiCounter, num: 50, radius: 400)
    }

    // MARK: - Helpers

    private var navigationTitle: String {
        if let context = replyContext {
            switch context.mode {
            case .reply, .replyAll:
                return "Re: \(context.email.subject)"
            case .forward:
                return "Fwd: \(context.email.subject)"
            }
        }
        return "New Message"
    }

    private func setupFromReplyContext() {
        guard let context = replyContext else { return }

        switch context.mode {
        case .reply:
            to = context.email.fromAddress
            subject = context.email.subject.hasPrefix("Re:") ? context.email.subject : "Re: \(context.email.subject)"
            emailBody = buildQuotedBody(from: context.email)

        case .replyAll:
            to = context.email.fromAddress
            let otherRecipients = context.email.toAddresses.filter { $0 != activeAccount?.emailAddress }
            let otherCc = context.email.ccAddresses.filter { $0 != activeAccount?.emailAddress }
            cc = (otherRecipients + otherCc).joined(separator: ", ")
            if !cc.isEmpty { showCcBcc = true }
            subject = context.email.subject.hasPrefix("Re:") ? context.email.subject : "Re: \(context.email.subject)"
            emailBody = buildQuotedBody(from: context.email)

        case .forward:
            subject = context.email.subject.hasPrefix("Fwd:") ? context.email.subject : "Fwd: \(context.email.subject)"
            emailBody = buildForwardedBody(from: context.email)
        }
    }

    private func buildQuotedBody(from email: Email) -> String {
        let dateStr = email.date.formatted(date: .abbreviated, time: .shortened)
        var body = "\n\n"
        body += "On \(dateStr), \(email.senderDisplayName) <\(email.fromAddress)> wrote:\n"
        body += "> "
        body += (email.textBody ?? "").replacingOccurrences(of: "\n", with: "\n> ")
        return body
    }

    private func buildForwardedBody(from email: Email) -> String {
        var body = "\n\n"
        body += "---------- Forwarded message ----------\n"
        body += "From: \(email.senderDisplayName) <\(email.fromAddress)>\n"
        body += "Date: \(email.date.formatted(date: .abbreviated, time: .shortened))\n"
        body += "Subject: \(email.subject)\n"
        body += "To: \(email.toAddresses.joined(separator: ", "))\n\n"
        body += email.textBody ?? ""
        return body
    }

    private func sendEmail() async {
        guard let account = activeAccount else {
            sendError = "No account selected"
            return
        }

        isSending = true
        sendError = nil

        let smtpService = SMTPService(account: account)

        do {
            try await smtpService.connect()

            let toRecipients = parseRecipients(to)
            let ccRecipients = parseRecipients(cc)
            let bccRecipients = parseRecipients(bcc)

            if let context = replyContext, context.mode == .reply || context.mode == .replyAll {
                try await smtpService.sendReply(
                    to: context.email,
                    body: emailBody,
                    replyAll: context.mode == .replyAll
                )
            } else if let context = replyContext, context.mode == .forward {
                try await smtpService.forwardEmail(
                    context.email,
                    to: toRecipients,
                    body: emailBody
                )
            } else {
                let outgoing = OutgoingEmail(
                    toAddresses: toRecipients,
                    ccAddresses: ccRecipients,
                    bccAddresses: bccRecipients,
                    subject: subject,
                    textBody: emailBody
                )
                try await smtpService.sendEmail(outgoing)
            }

            await smtpService.disconnect()

            if showConfettiOnSend {
                await MainActor.run { confettiCounter += 1 }
                try? await Task.sleep(for: .seconds(1.5))
            }

            await MainActor.run {
                tabManager.currentReplyContext = nil
                if let currentTab = tabManager.currentTab {
                    tabManager.closeTab(currentTab.id)
                }
            }

        } catch {
            sendError = error.localizedDescription
        }

        isSending = false
    }

    private func parseRecipients(_ field: String) -> [String] {
        field
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Field Row

private struct ComposeFieldRow<Content: View>: View {
    let label: String
    var showDivider: Bool = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(width: 56, alignment: .leading)

                content
                    .font(.subheadline)
            }
            .padding(.vertical, 10)

            if showDivider {
                Divider()
            }
        }
    }
}

// MARK: - Toolbar Button

private struct ToolbarButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.subheadline)
            }
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isActive ? Color.accentColor.opacity(0.1) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Panel

private struct ComposeAIPanel: View {
    @Binding var emailBody: String
    let subject: String
    let onDismiss: () -> Void

    @State private var prompt = ""
    @State private var isGenerating = false
    @State private var suggestions: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                Text("AI Assistant")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Quick actions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick actions")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)

                        ComposeFlowLayout(spacing: 6) {
                            QuickActionChip(label: "Formal", icon: "building.2") {
                                Task { await applyAction("Make it formal") }
                            }
                            QuickActionChip(label: "Casual", icon: "face.smiling") {
                                Task { await applyAction("Make it casual") }
                            }
                            QuickActionChip(label: "Shorter", icon: "arrow.down.left.and.arrow.up.right") {
                                Task { await applyAction("Make it shorter") }
                            }
                            QuickActionChip(label: "Fix grammar", icon: "textformat.abc") {
                                Task { await applyAction("Fix grammar") }
                            }
                        }
                        .disabled(emailBody.isEmpty || isGenerating)
                    }

                    Divider()

                    // Custom input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)

                        HStack(spacing: 8) {
                            TextField("Add closing, expand point...", text: $prompt)
                                .textFieldStyle(.plain)
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))

                            Button {
                                Task { await applyAction(prompt) }
                            } label: {
                                Group {
                                    if isGenerating {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                    } else {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(
                                    prompt.isEmpty || isGenerating ? Color.secondary.opacity(0.5) : Color.accentColor,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(prompt.isEmpty || isGenerating)
                        }
                    }

                    // Suggestions
                    if !suggestions.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggestions")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)

                            ForEach(suggestions, id: \.self) { suggestion in
                                Button {
                                    emailBody = suggestion
                                    suggestions = []
                                } label: {
                                    Text(suggestion)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(.background)
    }

    private func applyAction(_ action: String) async {
        isGenerating = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        suggestions = [
            "Dear Team,\n\nI hope this message finds you well. \(emailBody)\n\nBest regards",
            "Hi,\n\n\(emailBody)\n\nThanks!"
        ]

        isGenerating = false
        prompt = ""
    }
}

// MARK: - Quick Action Chip

private struct QuickActionChip: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

private struct ComposeFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    ComposeView(draftId: nil)
        .environmentObject(TabManager())
        .modelContainer(for: [Account.self])
        .frame(width: 700, height: 500)
}
