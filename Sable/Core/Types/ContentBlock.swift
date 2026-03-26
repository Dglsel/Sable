import Foundation

// MARK: - Content Block

/// A single renderable block within a message.
/// Messages can contain multiple blocks (text, tool calls, errors, etc.)
/// rendered sequentially in a VStack.
enum ContentBlock: Codable, Identifiable {
    case text(String)
    case toolCall(ToolCallBlock)
    case error(ErrorBlock)
    case image(ImageAttachment)

    var id: String {
        switch self {
        case .text(let s): "text-\(s.hashValue)"
        case .toolCall(let b): "tool-\(b.id)"
        case .error(let b): "error-\(b.id)"
        case .image(let a): "image-\(a.id)"
        }
    }
}

// MARK: - Tool Call Block

struct ToolCallBlock: Codable, Identifiable {
    var id: String = UUID().uuidString
    let toolName: String
    let input: String?
    let output: String?
    let status: ToolStatus
    let durationMs: Int?
}

enum ToolStatus: String, Codable {
    case running
    case success
    case failed
    case pendingApproval
}

// MARK: - Error Block

struct ErrorBlock: Codable, Identifiable {
    var id: String = UUID().uuidString
    let summary: String
    let technicalDetail: String?
    let isRetryable: Bool
}

// MARK: - Image Attachment

struct ImageAttachment: Codable, Identifiable {
    var id: String = UUID().uuidString
    let filename: String
    /// Absolute file path to the image on disk.
    let filePath: String
}

// MARK: - Chat Attachment (sent with messages)

/// Attachment info passed from ChatInputBar to ChatHomeView for API submission.
struct ChatAttachment: Identifiable, Sendable {
    let id = UUID()
    let filename: String
    let filePath: String
    let isImage: Bool
    let content: String?
}

enum AttachmentPromptBuilder {
    static func inlineText(for attachment: ChatAttachment) -> String? {
        if let content = attachment.content, !content.isEmpty {
            return content
        }

        let url = URL(fileURLWithPath: attachment.filePath)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func fileTag(for attachment: ChatAttachment) -> String? {
        guard let text = inlineText(for: attachment) else { return nil }
        return "<file name=\"\(attachment.filename)\">\n\(text)\n</file>"
    }
}

// MARK: - Response Metadata

struct ResponseMetadata: Codable {
    let modelName: String?
    let tokenCount: Int?
    let durationMs: Int?
}

// MARK: - Parsed Agent Response

struct ParsedAgentResponse {
    let blocks: [ContentBlock]
    let plainText: String
    let metadata: ResponseMetadata?
}
