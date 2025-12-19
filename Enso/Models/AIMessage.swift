import Foundation
import SwiftData

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case toolResult
}

@Model
final class AIMessage {
    @Attribute(.unique) var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date

    var toolCallsJson: String?

    var conversation: AIConversation?

    init(
        role: MessageRole,
        content: String
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }

    var isFromUser: Bool {
        role == .user
    }

    var isFromAssistant: Bool {
        role == .assistant
    }
}
