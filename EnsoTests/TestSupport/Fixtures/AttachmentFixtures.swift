//
//  AttachmentFixtures.swift
//  EnsoTests
//

import Foundation
@testable import Enso

/// Factory for creating Attachment test fixtures
enum AttachmentFixtures {

    // MARK: - Basic Factory

    /// Create a test attachment with customizable properties
    static func createAttachment(
        filename: String = "document.pdf",
        mimeType: String = "application/pdf",
        size: Int64 = 1024,
        contentId: String? = nil,
        isInline: Bool = false,
        isDownloaded: Bool = false,
        localPath: String? = nil
    ) -> Attachment {
        let attachment = Attachment(
            filename: filename,
            mimeType: mimeType,
            size: size,
            contentId: contentId,
            isInline: isInline
        )
        attachment.isDownloaded = isDownloaded
        attachment.localPath = localPath
        return attachment
    }

    // MARK: - Document Types

    /// Create a PDF attachment
    static func createPDFAttachment(
        filename: String = "document.pdf",
        size: Int64 = 102400 // 100 KB
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "application/pdf",
            size: size
        )
    }

    /// Create a Word document attachment
    static func createWordAttachment(
        filename: String = "document.docx",
        size: Int64 = 51200 // 50 KB
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            size: size
        )
    }

    /// Create an Excel spreadsheet attachment
    static func createExcelAttachment(
        filename: String = "spreadsheet.xlsx",
        size: Int64 = 76800 // 75 KB
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            size: size
        )
    }

    /// Create a PowerPoint presentation attachment
    static func createPowerPointAttachment(
        filename: String = "presentation.pptx",
        size: Int64 = 2097152 // 2 MB
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            size: size
        )
    }

    /// Create a plain text attachment
    static func createTextAttachment(
        filename: String = "notes.txt",
        size: Int64 = 1024 // 1 KB
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "text/plain",
            size: size
        )
    }

    // MARK: - Image Types

    /// Create a JPEG image attachment
    static func createJPEGAttachment(
        filename: String = "photo.jpg",
        size: Int64 = 512000, // 500 KB
        isInline: Bool = false
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "image/jpeg",
            size: size,
            isInline: isInline
        )
    }

    /// Create a PNG image attachment
    static func createPNGAttachment(
        filename: String = "screenshot.png",
        size: Int64 = 256000, // 250 KB
        isInline: Bool = false
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "image/png",
            size: size,
            isInline: isInline
        )
    }

    /// Create a GIF image attachment
    static func createGIFAttachment(
        filename: String = "animation.gif",
        size: Int64 = 1048576 // 1 MB
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "image/gif",
            size: size
        )
    }

    /// Create an inline image (for HTML emails)
    static func createInlineImage(
        filename: String = "inline-image.png",
        contentId: String = "image001"
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "image/png",
            size: 102400,
            contentId: contentId,
            isInline: true
        )
    }

    // MARK: - Media Types

    /// Create a video attachment
    static func createVideoAttachment(
        filename: String = "video.mp4",
        size: Int64 = 10485760 // 10 MB
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "video/mp4",
            size: size
        )
    }

    /// Create an audio attachment
    static func createAudioAttachment(
        filename: String = "recording.mp3",
        size: Int64 = 5242880 // 5 MB
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "audio/mpeg",
            size: size
        )
    }

    // MARK: - Archive Types

    /// Create a ZIP archive attachment
    static func createZipAttachment(
        filename: String = "archive.zip",
        size: Int64 = 5242880 // 5 MB
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "application/zip",
            size: size
        )
    }

    // MARK: - State Variations

    /// Create a downloaded attachment
    static func createDownloadedAttachment(
        filename: String = "downloaded.pdf",
        localPath: String = "/tmp/downloaded.pdf"
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "application/pdf",
            size: 102400,
            isDownloaded: true,
            localPath: localPath
        )
    }

    /// Create a large attachment
    static func createLargeAttachment(
        filename: String = "large-file.zip",
        size: Int64 = 104857600 // 100 MB
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "application/zip",
            size: size
        )
    }

    /// Create a small attachment
    static func createSmallAttachment(
        filename: String = "tiny.txt",
        size: Int64 = 100 // 100 bytes
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: "text/plain",
            size: size
        )
    }

    // MARK: - Batch Creation

    /// Create a set of common attachment types
    static func createCommonAttachmentSet() -> [Attachment] {
        [
            createPDFAttachment(),
            createWordAttachment(),
            createJPEGAttachment(),
            createZipAttachment()
        ]
    }

    /// Create multiple attachments
    static func createMultipleAttachments(count: Int = 3) -> [Attachment] {
        (1...count).map { index in
            createAttachment(
                filename: "file\(index).pdf",
                size: Int64(index) * 1024
            )
        }
    }

    // MARK: - Edge Cases

    /// Create an attachment with unusual MIME type
    static func createUnknownTypeAttachment(
        filename: String = "unknown.xyz",
        mimeType: String = "application/octet-stream"
    ) -> Attachment {
        createAttachment(
            filename: filename,
            mimeType: mimeType,
            size: 1024
        )
    }

    /// Create an attachment with special characters in filename
    static func createSpecialCharacterFilename() -> Attachment {
        createAttachment(
            filename: "file with spaces & special (chars).pdf",
            mimeType: "application/pdf",
            size: 1024
        )
    }
}
