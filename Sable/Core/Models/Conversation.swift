import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation) var messages: [Message]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isPinned: Bool = false,
        messages: [Message] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.messages = messages
    }

    var previewText: String {
        messages
            .sorted { $0.createdAt < $1.createdAt }
            .last?
            .content ?? ""
    }
}
