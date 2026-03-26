import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var roleRawValue: String
    var content: String
    var createdAt: Date
    var replyLanguageRawValue: String
    var isError: Bool = false
    var isStreaming: Bool = false
    var conversation: Conversation?

    /// JSON-encoded array of ContentBlock for structured rendering.
    /// When nil, falls back to rendering `content` as plain text.
    var blocksJSON: String?

    /// JSON-encoded ResponseMetadata (model name, token count, duration).
    var metadataJSON: String?

    /// Model's reasoning/thinking content, displayed in a collapsible block.
    var reasoningContent: String?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        createdAt: Date = .now,
        replyLanguage: ReplyLanguage = .automatic,
        isError: Bool = false,
        conversation: Conversation? = nil,
        blocks: [ContentBlock]? = nil,
        metadata: ResponseMetadata? = nil
    ) {
        self.id = id
        self.roleRawValue = role.rawValue
        self.content = content
        self.createdAt = createdAt
        self.replyLanguageRawValue = replyLanguage.rawValue
        self.isError = isError
        self.conversation = conversation
        self.blocksJSON = blocks.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) }
        self.metadataJSON = metadata.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) }
    }

    // MARK: - Structured Content

    /// Decoded content blocks. Falls back to a single text block from `content`.
    var contentBlocks: [ContentBlock] {
        if let json = blocksJSON,
           let data = json.data(using: .utf8),
           let blocks = try? JSONDecoder().decode([ContentBlock].self, from: data),
           !blocks.isEmpty {
            return blocks
        }
        // Fallback: wrap plain content as a single text block
        if isError {
            return [.error(ErrorBlock(summary: content, technicalDetail: nil, isRetryable: false))]
        }
        return [.text(content)]
    }

    /// Decoded response metadata, if available.
    var responseMetadata: ResponseMetadata? {
        guard let json = metadataJSON,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ResponseMetadata.self, from: data)
    }

    var role: MessageRole {
        get { MessageRole(rawValue: roleRawValue) ?? .assistant }
        set { roleRawValue = newValue.rawValue }
    }

    var replyLanguage: ReplyLanguage {
        get { ReplyLanguage(rawValue: replyLanguageRawValue) ?? .automatic }
        set { replyLanguageRawValue = newValue.rawValue }
    }
}
