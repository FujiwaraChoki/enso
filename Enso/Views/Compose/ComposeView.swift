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
        ZStack {
            // Background
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }

            HStack(spacing: 0) {
                // Main Content
                VStack(spacing: 20) {
                    // Header Section
                    VStack(spacing: 12) {
                        // From & Actions Row
                        HStack {
                            // From Picker
                            if accounts.count > 0 {
                                Menu {
                                    ForEach(accounts) { account in
                                        Button(account.emailAddress) {
                                            selectedAccountId = account.id
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text("From:")
                                            .foregroundStyle(.secondary)
                                        Text(activeAccount?.emailAddress ?? "Select Account")
                                            .foregroundStyle(.primary)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect(.regular, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            // Cc/Bcc Toggle
                            if !showCcBcc {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showCcBcc = true
                                    }
                                } label: {
                                    Text("Cc/Bcc")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .glassEffect(.regular, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        // Input Fields
                        VStack(spacing: 12) {
                            GlassTextField(
                                title: "To",
                                placeholder: "Recipient",
                                text: $to,
                                icon: "person"
                            )
                            .focused($focusedField, equals: .to)

                            if showCcBcc {
                                HStack(spacing: 12) {
                                    GlassTextField(
                                        title: "Cc",
                                        placeholder: "Copy",
                                        text: $cc,
                                        icon: "person.2"
                                    )
                                    .focused($focusedField, equals: .cc)

                                    GlassTextField(
                                        title: "Bcc",
                                        placeholder: "Blind Copy",
                                        text: $bcc,
                                        icon: "eye.slash"
                                    )
                                    .focused($focusedField, equals: .bcc)
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            GlassTextField(
                                title: "Subject",
                                placeholder: "What's this about?",
                                text: $subject,
                                icon: "text.alignleft"
                            )
                            .focused($focusedField, equals: .subject)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Body Section
                    ZStack(alignment: .topLeading) {
                        if emailBody.isEmpty {
                            Text("Start writing your message...")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 16)
                                .padding(.leading, 16)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $emailBody)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .focused($focusedField, equals: .body)
                            .padding(12)
                    }
                    .frame(maxHeight: .infinity)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 80) // Space for floating bar
                }

                // AI Panel
                if showAIAssistant {
                    Divider()
                        .ignoresSafeArea()

                    ComposeAIPanel(
                        emailBody: $emailBody,
                        subject: subject,
                        onDismiss: { showAIAssistant = false }
                    )
                    .frame(width: 320)
                    .transition(.move(edge: .trailing))
                }
            }

            // Floating Bottom Bar
            VStack {
                Spacer()
                HStack(spacing: 16) {
                    // Attach
                    Button {
                        // Attachment logic
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .help("Attach File")

                    // AI Toggle
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showAIAssistant.toggle()
                        }
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                            .foregroundStyle(showAIAssistant ? Color.accentColor : .secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .help("AI Assistant")

                    Spacer()

                    // Discard
                    Button {
                        tabManager.currentReplyContext = nil
                        if let currentTab = tabManager.currentTab {
                            tabManager.closeTab(currentTab.id)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .help("Discard Draft")

                    // Send Button
                    Button {
                        Task { await sendEmail() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSending {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 16, height: 16)
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14))
                            }
                            Text(isSending ? "Sending..." : "Send")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            canSend ? Color.accentColor : Color.secondary.opacity(0.3),
                            in: Capsule()
                        )
                        .shadow(color: canSend ? Color.accentColor.opacity(0.3) : .clear, radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .keyboardShortcut(.return, modifiers: .command)
                }
                .padding(12)
                .glassEffect(.regular, in: Capsule())
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .padding(.trailing, showAIAssistant ? 320 : 0) // Adjust for AI panel
        }
        .background(
            Image("MeshGradient") // Assuming there's a mesh gradient or similar, or just use background
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .opacity(0.1)
                .background(Color(nsColor: .windowBackgroundColor))
        )
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
                let replyData = SMTPService.ReplyEmailData(from: context.email)
                try await smtpService.sendReply(
                    to: replyData,
                    body: emailBody,
                    replyAll: context.mode == .replyAll
                )
            } else if let context = replyContext, context.mode == .forward {
                let forwardData = SMTPService.ForwardEmailData(from: context.email)
                try await smtpService.forwardEmail(
                    forwardData,
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("AI Assistant")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(.ultraThinMaterial)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Quick actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ComposeFlowLayout(spacing: 8) {
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom Request")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 8) {
                            TextField("Ask AI to rewrite...", text: $prompt)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

                            Button {
                                Task { await applyAction(prompt) }
                            } label: {
                                Group {
                                    if isGenerating {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                    } else {
                                        Image(systemName: "arrow.up")
                                            .fontWeight(.bold)
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    prompt.isEmpty || isGenerating ? Color.secondary.opacity(0.5) : Color.accentColor,
                                    in: Circle()
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(prompt.isEmpty || isGenerating)
                        }
                    }

                    // Suggestions
                    if !suggestions.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggestions")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            ForEach(suggestions, id: \.self) { suggestion in
                                Button {
                                    emailBody = suggestion
                                    suggestions = []
                                } label: {
                                    Text(suggestion)
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(.regularMaterial)
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
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.subheadline)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
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
        .frame(width: 800, height: 600)
}
