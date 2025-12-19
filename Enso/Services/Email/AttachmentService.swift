//
//  AttachmentService.swift
//  Enso
//

import Foundation
import SwiftUI
import SwiftData
import SwiftMail
import UniformTypeIdentifiers

/// Service for handling email attachments
@MainActor
@Observable
final class AttachmentService {

    // MARK: - Types

    enum AttachmentError: LocalizedError {
        case downloadFailed(Error)
        case fileNotFound
        case invalidData
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .downloadFailed(let error):
                return "Download failed: \(error.localizedDescription)"
            case .fileNotFound:
                return "File not found"
            case .invalidData:
                return "Invalid attachment data"
            case .saveFailed(let error):
                return "Failed to save: \(error.localizedDescription)"
            }
        }
    }

    struct DownloadProgress: Identifiable {
        let id: UUID
        var progress: Double
        var isComplete: Bool
        var error: String?
    }

    // MARK: - Properties

    private(set) var activeDownloads: [UUID: DownloadProgress] = [:]
    private let attachmentsDirectory: URL
    private let keychainService: KeychainService

    // MARK: - Initialization

    init(keychainService: KeychainService = .shared) {
        self.keychainService = keychainService

        // Create attachments directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.attachmentsDirectory = appSupport.appendingPathComponent("Enso/Attachments", isDirectory: true)

        try? FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Download Operations

    /// Download an attachment from the server
    func downloadAttachment(
        _ attachment: Attachment,
        from email: Email,
        modelContext: ModelContext
    ) async throws -> URL {
        guard let account = email.account,
              let folder = email.folder else {
            throw AttachmentError.fileNotFound
        }

        // Check if already downloaded
        if let localPath = attachment.localPath,
           FileManager.default.fileExists(atPath: localPath) {
            return URL(fileURLWithPath: localPath)
        }

        // Track progress
        activeDownloads[attachment.id] = DownloadProgress(id: attachment.id, progress: 0, isComplete: false)

        do {
            let imapService = IMAPService(account: account, keychainService: keychainService)
            try await imapService.connect()

            // Fetch the full message to get attachment data
            let message = try await imapService.fetchMessage(mailbox: folder.path, uid: email.uid)

            await imapService.disconnect()

            // Find the attachment data in the message
            guard message.attachments.contains(where: { $0.filename == attachment.filename }) else {
                throw AttachmentError.fileNotFound
            }

            // We need to fetch the actual data - this is a simplified version
            // In a real implementation, you'd fetch the specific MIME part
            activeDownloads[attachment.id]?.progress = 0.5

            // Create local file path
            let sanitizedFilename = sanitizeFilename(attachment.filename)
            let emailDir = attachmentsDirectory.appendingPathComponent(email.id.uuidString, isDirectory: true)
            try? FileManager.default.createDirectory(at: emailDir, withIntermediateDirectories: true)
            let localURL = emailDir.appendingPathComponent(sanitizedFilename)

            // For now, create a placeholder - in real implementation, save actual data
            // This would come from the IMAP fetch body part operation
            if let bodyData = email.textBody?.data(using: .utf8) {
                try bodyData.write(to: localURL)
            }

            // Update attachment record
            attachment.isDownloaded = true
            attachment.localPath = localURL.path
            try modelContext.save()

            activeDownloads[attachment.id]?.progress = 1.0
            activeDownloads[attachment.id]?.isComplete = true

            return localURL

        } catch {
            activeDownloads[attachment.id]?.error = error.localizedDescription
            throw AttachmentError.downloadFailed(error)
        }
    }

    /// Open attachment in default app
    func openAttachment(_ attachment: Attachment) throws {
        guard let localPath = attachment.localPath else {
            throw AttachmentError.fileNotFound
        }

        let url = URL(fileURLWithPath: localPath)
        NSWorkspace.shared.open(url)
    }

    /// Quick Look attachment
    func quickLookAttachment(_ attachment: Attachment) throws -> URL {
        guard let localPath = attachment.localPath else {
            throw AttachmentError.fileNotFound
        }
        return URL(fileURLWithPath: localPath)
    }

    /// Save attachment to user-chosen location
    func saveAttachment(_ attachment: Attachment, to destinationURL: URL) throws {
        guard let localPath = attachment.localPath else {
            throw AttachmentError.fileNotFound
        }

        let sourceURL = URL(fileURLWithPath: localPath)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw AttachmentError.saveFailed(error)
        }
    }

    // MARK: - Compose Attachment Operations

    /// Add attachment to compose from file URL
    func createOutgoingAttachment(from fileURL: URL) throws -> OutgoingAttachment {
        return try OutgoingAttachment(fileURL: fileURL)
    }

    /// Add attachment from dropped data
    func createOutgoingAttachment(from data: Data, filename: String, mimeType: String) -> OutgoingAttachment {
        return OutgoingAttachment(filename: filename, mimeType: mimeType, data: data)
    }

    // MARK: - Cleanup

    /// Delete downloaded attachment files for an email
    func cleanupAttachments(for emailId: UUID) {
        let emailDir = attachmentsDirectory.appendingPathComponent(emailId.uuidString)
        try? FileManager.default.removeItem(at: emailDir)
    }

    /// Delete all cached attachments
    func clearAllCachedAttachments() {
        try? FileManager.default.removeItem(at: attachmentsDirectory)
        try? FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
    }

    /// Get total cache size
    func getCacheSize() -> Int64 {
        var size: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: attachmentsDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }

    // MARK: - Helpers

    private func sanitizeFilename(_ filename: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return filename.components(separatedBy: invalidChars).joined(separator: "_")
    }
}

// MARK: - Environment Key

private struct AttachmentServiceKey: EnvironmentKey {
    static let defaultValue: AttachmentService = AttachmentService()
}

extension EnvironmentValues {
    var attachmentService: AttachmentService {
        get { self[AttachmentServiceKey.self] }
        set { self[AttachmentServiceKey.self] = newValue }
    }
}
