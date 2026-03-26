import SwiftUI

/// Dispatches content blocks to their appropriate renderers.
/// This is the core expansion point: new block types get a new case here.
struct MessageContentView: View {
    let message: Message
    var onRetry: (() -> Void)?

    private var isUser: Bool { message.role == .user && !message.isError }

    var body: some View {
        let blocks = message.contentBlocks

        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            ForEach(blocks) { block in
                blockView(for: block)
            }
        }
    }

    @ViewBuilder
    private func blockView(for block: ContentBlock) -> some View {
        switch block {
        case .text(let text):
            TextBlockView(text: text, role: message.role, isError: false)

        case .error(let errorBlock):
            ErrorBlockView(block: errorBlock, onRetry: onRetry)

        case .toolCall(let toolBlock):
            ActionCardView(block: toolBlock)

        case .image(let imageAttachment):
            ImageAttachmentView(attachment: imageAttachment)
        }
    }
}
