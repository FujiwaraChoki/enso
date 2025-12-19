import Foundation
import SwiftData

enum AIContextType: String, Codable {
    case general
    case emailContext
    case compose
}

@Model
final class AIConversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    var contextEmailId: UUID?
    var contextType: AIContextType

    @Relationship(deleteRule: .cascade, inverse: \AIMessage.conversation)
    var messages: [AIMessage] = []

    init(
        title: String = "New Conversation",
        contextType: AIContextType = .general,
        contextEmailId: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.contextType = contextType
        self.contextEmailId = contextEmailId
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var sortedMessages: [AIMessage] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }
}
