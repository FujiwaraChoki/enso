//
//  DraftService.swift
//  Enso
//

import Foundation
import SwiftUI
import SwiftData

/// Service for managing email drafts
@MainActor
@Observable
final class DraftService {

    // MARK: - Types

    struct DraftEmail: Codable, Identifiable {
        var id: UUID
        var accountId: UUID
        var toAddresses: [String]
        var ccAddresses: [String]
        var bccAddresses: [String]
        var subject: String
        var textBody: String
        var htmlBody: String?
        var attachmentPaths: [String]
        var replyToEmailId: UUID?
        var replyMode: String? // "reply", "replyAll", "forward"
        var createdDate: Date
        var modifiedDate: Date

        init(
            accountId: UUID,
            toAddresses: [String] = [],
            ccAddresses: [String] = [],
            bccAddresses: [String] = [],
            subject: String = "",
            textBody: String = "",
            htmlBody: String? = nil,
            replyToEmailId: UUID? = nil,
            replyMode: String? = nil
        ) {
            self.id = UUID()
            self.accountId = accountId
            self.toAddresses = toAddresses
            self.ccAddresses = ccAddresses
            self.bccAddresses = bccAddresses
            self.subject = subject
            self.textBody = textBody
            self.htmlBody = htmlBody
            self.attachmentPaths = []
            self.replyToEmailId = replyToEmailId
            self.replyMode = replyMode
            self.createdDate = Date()
            self.modifiedDate = Date()
        }
    }

    // MARK: - Properties

    private(set) var drafts: [DraftEmail] = []
    private let draftsURL: URL

    // MARK: - Initialization

    init() {
        // Store drafts in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let ensoDir = appSupport.appendingPathComponent("Enso", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: ensoDir, withIntermediateDirectories: true)

        self.draftsURL = ensoDir.appendingPathComponent("drafts.json")
        loadDrafts()
    }

    // MARK: - CRUD Operations

    /// Create a new draft
    @discardableResult
    func createDraft(accountId: UUID) -> DraftEmail {
        let draft = DraftEmail(accountId: accountId)
        drafts.insert(draft, at: 0)
        saveDrafts()
        return draft
    }

    /// Create draft from reply context
    @discardableResult
    func createDraft(
        accountId: UUID,
        replyTo email: Email,
        mode: ReplyMode
    ) -> DraftEmail {
        var draft = DraftEmail(
            accountId: accountId,
            replyToEmailId: email.id,
            replyMode: mode.rawValue
        )

        switch mode {
        case .reply:
            draft.toAddresses = [email.fromAddress]
            draft.subject = email.subject.hasPrefix("Re:") ? email.subject : "Re: \(email.subject)"

        case .replyAll:
            draft.toAddresses = [email.fromAddress]
            draft.ccAddresses = email.toAddresses + email.ccAddresses
            draft.subject = email.subject.hasPrefix("Re:") ? email.subject : "Re: \(email.subject)"

        case .forward:
            draft.subject = email.subject.hasPrefix("Fwd:") ? email.subject : "Fwd: \(email.subject)"
        }

        drafts.insert(draft, at: 0)
        saveDrafts()
        return draft
    }

    /// Update an existing draft
    func updateDraft(_ draft: DraftEmail) {
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            var updated = draft
            updated.modifiedDate = Date()
            drafts[index] = updated
            saveDrafts()
        }
    }

    /// Save draft with all fields
    func saveDraft(
        id: UUID,
        toAddresses: [String],
        ccAddresses: [String],
        bccAddresses: [String],
        subject: String,
        textBody: String,
        attachmentPaths: [String] = []
    ) {
        if let index = drafts.firstIndex(where: { $0.id == id }) {
            drafts[index].toAddresses = toAddresses
            drafts[index].ccAddresses = ccAddresses
            drafts[index].bccAddresses = bccAddresses
            drafts[index].subject = subject
            drafts[index].textBody = textBody
            drafts[index].attachmentPaths = attachmentPaths
            drafts[index].modifiedDate = Date()
            saveDrafts()
        }
    }

    /// Delete a draft
    func deleteDraft(_ id: UUID) {
        drafts.removeAll { $0.id == id }
        saveDrafts()
    }

    /// Delete all drafts
    func deleteAllDrafts() {
        drafts.removeAll()
        saveDrafts()
    }

    /// Get draft by ID
    func getDraft(_ id: UUID) -> DraftEmail? {
        drafts.first { $0.id == id }
    }

    /// Get drafts for account
    func getDrafts(for accountId: UUID) -> [DraftEmail] {
        drafts.filter { $0.accountId == accountId }
    }

    // MARK: - Auto-save Timer

    private var autoSaveTimer: Timer?
    private var pendingChanges: DraftEmail?

    /// Schedule auto-save for a draft
    func scheduleAutoSave(_ draft: DraftEmail) {
        pendingChanges = draft

        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let pending = self.pendingChanges else { return }
                self.updateDraft(pending)
                self.pendingChanges = nil
            }
        }
    }

    /// Force save any pending changes
    func flushPendingChanges() {
        autoSaveTimer?.invalidate()
        if let pending = pendingChanges {
            updateDraft(pending)
            pendingChanges = nil
        }
    }

    // MARK: - Persistence

    private func loadDrafts() {
        guard FileManager.default.fileExists(atPath: draftsURL.path) else { return }

        do {
            let data = try Data(contentsOf: draftsURL)
            drafts = try JSONDecoder().decode([DraftEmail].self, from: data)
        } catch {
            print("Failed to load drafts: \(error)")
        }
    }

    private func saveDrafts() {
        do {
            let data = try JSONEncoder().encode(drafts)
            try data.write(to: draftsURL)
        } catch {
            print("Failed to save drafts: \(error)")
        }
    }
}

// MARK: - ReplyMode Extension

extension ReplyMode {
    var rawValue: String {
        switch self {
        case .reply: return "reply"
        case .replyAll: return "replyAll"
        case .forward: return "forward"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "reply": self = .reply
        case "replyAll": self = .replyAll
        case "forward": self = .forward
        default: return nil
        }
    }
}

// MARK: - Environment Key

private struct DraftServiceKey: EnvironmentKey {
    static let defaultValue: DraftService = DraftService()
}

extension EnvironmentValues {
    var draftService: DraftService {
        get { self[DraftServiceKey.self] }
        set { self[DraftServiceKey.self] = newValue }
    }
}
