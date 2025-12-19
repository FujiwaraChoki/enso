//
//  AttachmentTests.swift
//  EnsoTests
//

import XCTest
import SwiftData
@testable import Enso

final class AttachmentTests: XCTestCase {

    // MARK: - icon Tests (MIME Type Mapping)

    func test_icon_returnsPhoto_forImageTypes() {
        let jpegAttachment = AttachmentFixtures.createJPEGAttachment()
        let pngAttachment = AttachmentFixtures.createPNGAttachment()
        let gifAttachment = AttachmentFixtures.createGIFAttachment()

        XCTAssertEqual(jpegAttachment.icon, "photo")
        XCTAssertEqual(pngAttachment.icon, "photo")
        XCTAssertEqual(gifAttachment.icon, "photo")
    }

    func test_icon_returnsVideo_forVideoTypes() {
        let attachment = AttachmentFixtures.createVideoAttachment()

        XCTAssertEqual(attachment.icon, "video")
    }

    func test_icon_returnsWaveform_forAudioTypes() {
        let attachment = AttachmentFixtures.createAudioAttachment()

        XCTAssertEqual(attachment.icon, "waveform")
    }

    func test_icon_returnsDocRichtext_forPDF() {
        let attachment = AttachmentFixtures.createPDFAttachment()

        XCTAssertEqual(attachment.icon, "doc.richtext")
    }

    func test_icon_returnsDocZipper_forArchives() {
        let zipAttachment = AttachmentFixtures.createZipAttachment()

        XCTAssertEqual(zipAttachment.icon, "doc.zipper")
    }

    func test_icon_returnsDocText_forWordDocuments() {
        let attachment = AttachmentFixtures.createWordAttachment()

        XCTAssertEqual(attachment.icon, "doc.text")
    }

    func test_icon_returnsTablecells_forSpreadsheets() {
        let attachment = AttachmentFixtures.createExcelAttachment()

        XCTAssertEqual(attachment.icon, "tablecells")
    }

    func test_icon_returnsPlayRectangle_forPresentations() {
        let attachment = AttachmentFixtures.createPowerPointAttachment()

        XCTAssertEqual(attachment.icon, "play.rectangle")
    }

    func test_icon_returnsDoc_forUnknownTypes() {
        let attachment = AttachmentFixtures.createUnknownTypeAttachment()

        XCTAssertEqual(attachment.icon, "doc")
    }

    func test_icon_handlesUppercaseMimeType() {
        let attachment = AttachmentFixtures.createAttachment(
            filename: "test.pdf",
            mimeType: "APPLICATION/PDF"
        )

        XCTAssertEqual(attachment.icon, "doc.richtext")
    }

    // MARK: - formattedSize Tests

    func test_formattedSize_formatsBytes() {
        let attachment = AttachmentFixtures.createSmallAttachment(size: 100)

        // ByteCountFormatter will format this
        XCTAssertFalse(attachment.formattedSize.isEmpty)
    }

    func test_formattedSize_formatsKilobytes() {
        let attachment = AttachmentFixtures.createAttachment(size: 1024)

        let formatted = attachment.formattedSize
        XCTAssertFalse(formatted.isEmpty)
    }

    func test_formattedSize_formatsMegabytes() {
        let attachment = AttachmentFixtures.createAttachment(size: 1048576) // 1 MB

        let formatted = attachment.formattedSize
        XCTAssertFalse(formatted.isEmpty)
    }

    func test_formattedSize_formatsLargeFiles() {
        let attachment = AttachmentFixtures.createLargeAttachment(size: 104857600) // 100 MB

        let formatted = attachment.formattedSize
        XCTAssertFalse(formatted.isEmpty)
    }

    // MARK: - Initialization Tests

    func test_init_setsDefaultValues() {
        let attachment = Attachment(
            filename: "test.pdf",
            mimeType: "application/pdf",
            size: 1024
        )

        XCTAssertFalse(attachment.isInline)
        XCTAssertFalse(attachment.isDownloaded)
        XCTAssertNil(attachment.contentId)
        XCTAssertNil(attachment.localPath)
    }

    func test_init_setsProvidedValues() {
        let attachment = Attachment(
            filename: "image.png",
            mimeType: "image/png",
            size: 2048,
            contentId: "cid123",
            isInline: true
        )

        XCTAssertEqual(attachment.filename, "image.png")
        XCTAssertEqual(attachment.mimeType, "image/png")
        XCTAssertEqual(attachment.size, 2048)
        XCTAssertEqual(attachment.contentId, "cid123")
        XCTAssertTrue(attachment.isInline)
    }

    // MARK: - State Tests

    func test_isDownloaded_canBeModified() {
        let attachment = AttachmentFixtures.createAttachment()

        attachment.isDownloaded = true

        XCTAssertTrue(attachment.isDownloaded)
    }

    func test_localPath_canBeSet() {
        let attachment = AttachmentFixtures.createAttachment()

        attachment.localPath = "/tmp/downloaded.pdf"

        XCTAssertEqual(attachment.localPath, "/tmp/downloaded.pdf")
    }

    // MARK: - Relationship Tests

    func test_email_startsNil() {
        let attachment = AttachmentFixtures.createAttachment()

        XCTAssertNil(attachment.email)
    }

    // MARK: - Fixture Tests

    func test_inlineImage_hasCorrectProperties() {
        let attachment = AttachmentFixtures.createInlineImage(contentId: "image001")

        XCTAssertTrue(attachment.isInline)
        XCTAssertEqual(attachment.contentId, "image001")
        XCTAssertTrue(attachment.mimeType.hasPrefix("image/"))
    }

    func test_downloadedAttachment_hasCorrectState() {
        let attachment = AttachmentFixtures.createDownloadedAttachment(
            localPath: "/tmp/test.pdf"
        )

        XCTAssertTrue(attachment.isDownloaded)
        XCTAssertEqual(attachment.localPath, "/tmp/test.pdf")
    }

    func test_commonAttachmentSet_containsVariety() {
        let attachments = AttachmentFixtures.createCommonAttachmentSet()

        XCTAssertEqual(attachments.count, 4)

        let mimeTypes = attachments.map { $0.mimeType }
        XCTAssertTrue(mimeTypes.contains { $0.contains("pdf") })
        XCTAssertTrue(mimeTypes.contains { $0.contains("word") || $0.contains("document") })
        XCTAssertTrue(mimeTypes.contains { $0.contains("image") })
        XCTAssertTrue(mimeTypes.contains { $0.contains("zip") })
    }

    func test_multipleAttachments_areCreated() {
        let attachments = AttachmentFixtures.createMultipleAttachments(count: 5)

        XCTAssertEqual(attachments.count, 5)

        // Each should have different filename
        let filenames = Set(attachments.map { $0.filename })
        XCTAssertEqual(filenames.count, 5)
    }

    func test_specialCharacterFilename_isCreated() {
        let attachment = AttachmentFixtures.createSpecialCharacterFilename()

        XCTAssertTrue(attachment.filename.contains(" "))
        XCTAssertTrue(attachment.filename.contains("&"))
        XCTAssertTrue(attachment.filename.contains("("))
    }

    // MARK: - Size Edge Cases

    func test_zeroSizeAttachment() {
        let attachment = AttachmentFixtures.createAttachment(size: 0)

        XCTAssertEqual(attachment.size, 0)
        XCTAssertFalse(attachment.formattedSize.isEmpty)
    }

    func test_veryLargeAttachment() {
        // 1 GB
        let attachment = AttachmentFixtures.createAttachment(size: 1073741824)

        XCTAssertFalse(attachment.formattedSize.isEmpty)
    }
}
