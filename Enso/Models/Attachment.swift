import Foundation
import SwiftData

@Model
final class Attachment {
    @Attribute(.unique) var id: UUID
    var filename: String
    var mimeType: String
    var size: Int64
    var contentId: String?

    var isInline: Bool
    var isDownloaded: Bool
    var localPath: String?

    var email: Email?

    init(
        filename: String,
        mimeType: String,
        size: Int64,
        contentId: String? = nil,
        isInline: Bool = false
    ) {
        self.id = UUID()
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.contentId = contentId
        self.isInline = isInline
        self.isDownloaded = false
    }

    var icon: String {
        switch mimeType.lowercased() {
        case let type where type.hasPrefix("image/"):
            return "photo"
        case let type where type.hasPrefix("video/"):
            return "video"
        case let type where type.hasPrefix("audio/"):
            return "waveform"
        case "application/pdf":
            return "doc.richtext"
        case let type where type.contains("zip") || type.contains("compressed"):
            return "doc.zipper"
        case let type where type.contains("word") || type.contains("document"):
            return "doc.text"
        case let type where type.contains("sheet") || type.contains("excel"):
            return "tablecells"
        case let type where type.contains("presentation") || type.contains("powerpoint"):
            return "play.rectangle"
        default:
            return "doc"
        }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
