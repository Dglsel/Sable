import os
import SwiftData
import SwiftUI

struct ChatHomeView: View {
    private static let logger = Logger(subsystem: "ai.sable", category: "ChatHomeView")
    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    let conversation: Conversation?
    let onCreateConversation: () -> Void

    @State private var isSending = false
    @State private var activeToolName: String?
    @State private var typewriter = TypewriterState()
    @State private var activeTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let conversation {
                VStack(spacing: 0) {
                    MessageListView(
                        conversation: conversation,
                        isSending: isSending,
                        activeToolName: activeToolName,
                        typewriter: typewriter,
                        onDeleteMessage: { message in
                            deleteMessage(message, from: conversation)
                        },
                        onRegenerate: {
                            regenerateLastResponse(in: conversation)
                        }
                    )
                    ChatInputBar(isSending: isSending, onSend: { prompt, attachments in
                        send(prompt: prompt, attachments: attachments, in: conversation)
                    }, onStop: {
                        stopGeneration(in: conversation)
                    })
                }
            } else {
                EmptyStateView(onCreateConversation: onCreateConversation)
            }
        }
        .onChange(of: conversation?.id) { oldID, newID in
            guard oldID != newID, activeTask != nil else { return }
            // Cancel the in-flight task so it doesn't write into the wrong conversation
            activeTask?.cancel()
            activeTask = nil
            typewriter.stop()
            container.gatewayService.cancelStreaming()
            activeToolName = nil
            isSending = false
        }
    }



    // MARK: - Send

    private func send(prompt: String, attachments: [ChatAttachment] = [], in conversation: Conversation, skipUserMessage: Bool = false) {
        guard !isSending else { return }

        // Classify attachments into three buckets:
        // 1. Images → send as input_image (base64)
        // 2. Gateway-supported files (PDF, JSON, plain text, markdown, HTML, CSV) → send as input_file
        // 3. Text-readable files (.swift, .py, .xml, etc.) → inline into prompt as <file> tags
        var apiAttachments: [OpenResponsesService.Attachment] = []
        var inlinedTextParts: [String] = []

        for att in attachments {
            let ext = (att.filename as NSString).pathExtension.lowercased()
            let url = URL(fileURLWithPath: att.filePath)

            if att.isImage {
                // Bucket 1: Images → API attachment
                guard let data = try? Data(contentsOf: url) else { continue }
                let mimeType = Self.imageMimeType(for: ext)
                apiAttachments.append(.init(
                    kind: .image, mimeType: mimeType,
                    base64Data: data.base64EncodedString(), fileName: att.filename
                ))
            } else if Self.gatewayFileTypes.contains(ext) {
                // Bucket 2: Gateway-supported binary files → API attachment
                guard let data = try? Data(contentsOf: url) else { continue }
                let mimeType = Self.gatewayFileMimeType(for: ext)
                apiAttachments.append(.init(
                    kind: .file, mimeType: mimeType,
                    base64Data: data.base64EncodedString(), fileName: att.filename
                ))
            } else if let tag = AttachmentPromptBuilder.fileTag(for: att) {
                // Bucket 3: Text-readable files → inline into prompt
                inlinedTextParts.append(tag)
            }
            // else: unsupported attachment with no extractable text — skip
        }

        // Build effective prompt: inlined file contents + user text
        let effectivePrompt: String
        if inlinedTextParts.isEmpty {
            effectivePrompt = prompt
        } else {
            effectivePrompt = (inlinedTextParts + [prompt]).joined(separator: "\n\n")
        }

        if !skipUserMessage {
            // Build content blocks: text + image thumbnails for display
            let imageAttachments = attachments.filter(\.isImage)
            var blocks: [ContentBlock]? = nil
            if !imageAttachments.isEmpty {
                var b: [ContentBlock] = [.text(prompt)]
                b += imageAttachments.map { .image(ImageAttachment(filename: $0.filename, filePath: $0.filePath)) }
                blocks = b
            }

            let userMessage = Message(
                role: .user,
                content: prompt,
                blocks: blocks
            )

            conversation.messages.append(userMessage)
            conversation.updatedAt = .now

            if conversation.title == L10n.string("sidebar.newConversation", default: "New Chat") {
                conversation.title = smartTitle(from: prompt)
            }

            modelContext.insert(userMessage)
            try? modelContext.save()
        }

        withAnimation(SableAnimation.enter(duration: SableAnimation.fast)) {
            isSending = true
        }
        let hasMediaAttachments = !apiAttachments.isEmpty

        activeTask = Task { @MainActor in
            // Pre-fetch any URLs in the prompt so the model can read web content
            let fetchedPages = await URLContentFetcher.fetchAll(in: effectivePrompt)
            guard !Task.isCancelled else { return }

            var finalPrompt = effectivePrompt
            if !fetchedPages.isEmpty {
                let webContext = fetchedPages.map(\.promptTag).joined(separator: "\n\n")
                finalPrompt = webContext + "\n\n" + effectivePrompt
            }

            let didStream = await sendViaStreaming(prompt: finalPrompt, conversation: conversation, attachments: apiAttachments)
            guard !Task.isCancelled else { return }
            if !didStream {
                if hasMediaAttachments {
                    let warning = ErrorBlock(
                        summary: "Images/files could not be sent — streaming unavailable, CLI fallback does not support media attachments.",
                        technicalDetail: "Check that the OpenClaw gateway is running and /v1/responses is enabled.",
                        isRetryable: true
                    )
                    withAnimation(SableAnimation.enter(duration: SableAnimation.slow)) {
                        isSending = false
                        appendErrorMessage(warning, to: conversation)
                    }
                } else {
                    await sendViaCLI(prompt: finalPrompt, conversation: conversation)
                }
            }
            activeTask = nil
        }
    }

    // MARK: - Stop Generation

    private func stopGeneration(in conversation: Conversation) {
        activeTask?.cancel()
        activeTask = nil
        typewriter.stop()
        container.gatewayService.cancelStreaming()

        // Finalize any in-progress streaming message with whatever text arrived so far
        if let streamingMsg = conversation.messages.last(where: { $0.isStreaming }) {
            streamingMsg.isStreaming = false
            if streamingMsg.content.isEmpty {
                // No content arrived — remove the empty message
                conversation.messages.removeAll { $0.id == streamingMsg.id }
                modelContext.delete(streamingMsg)
            }
            try? modelContext.save()
        }

        withAnimation(SableAnimation.move(duration: SableAnimation.fast)) {
            isSending = false
        }
    }

    // MARK: - File Type Classification

    /// File types that OpenClaw /v1/responses accepts as input_file
    private static let gatewayFileTypes: Set<String> = [
        "pdf", "json", "txt", "md", "markdown", "html", "htm", "csv"
    ]

    private static func imageMimeType(for ext: String) -> String {
        switch ext {
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "tiff": return "image/tiff"
        case "bmp": return "image/bmp"
        case "svg": return "image/svg+xml"
        default: return "image/jpeg"
        }
    }

    private static func gatewayFileMimeType(for ext: String) -> String {
        switch ext {
        case "pdf": return "application/pdf"
        case "json": return "application/json"
        case "txt": return "text/plain"
        case "md", "markdown": return "text/markdown"
        case "html", "htm": return "text/html"
        case "csv": return "text/csv"
        default: return "application/octet-stream"
        }
    }

    // MARK: - Streaming Path

    private func sendViaStreaming(prompt: String, conversation: Conversation, attachments: [OpenResponsesService.Attachment] = []) async -> Bool {
        let gateway = container.gatewayService

        do {
            let stream = try await gateway.sendMessageStreaming(prompt, context: conversation, attachments: attachments)

            let startTime = CFAbsoluteTimeGetCurrent()
            let streamingMsg = Message(
                role: .assistant,
                content: ""
            )
            streamingMsg.isStreaming = true

            // Insert before appending to conversation so the message is always
            // persisted, even if the stream is interrupted before `.final_`.
            modelContext.insert(streamingMsg)

            var accumulatedText = ""
            var accumulatedReasoning = ""
            var hasReceivedFirstDelta = false

            for await event in stream {
                switch event {
                case .retrying(let attempt, let maxAttempts):
                    withAnimation(SableAnimation.enter(duration: SableAnimation.fast)) {
                        activeToolName = "retry:\(attempt)/\(maxAttempts)"
                        isSending = true
                    }

                case .reasoningDelta(let text):
                    accumulatedReasoning += text
                    // Show reasoning activity in the thinking indicator
                    if activeToolName == nil {
                        withAnimation(SableAnimation.enter(duration: SableAnimation.fast)) {
                            activeToolName = "thinking"
                            isSending = true
                        }
                    }

                case .toolCall(let name):
                    withAnimation(SableAnimation.enter(duration: SableAnimation.fast)) {
                        activeToolName = name
                        isSending = true
                    }

                case .delta(let text):
                    if activeToolName != nil {
                        withAnimation(SableAnimation.exit(duration: SableAnimation.fast)) {
                            activeToolName = nil
                        }
                    }
                    accumulatedText += text
                    streamingMsg.content = accumulatedText

                    if !hasReceivedFirstDelta {
                        hasReceivedFirstDelta = true
                        withAnimation(SableAnimation.enter(duration: SableAnimation.slow)) {
                            conversation.messages.append(streamingMsg)
                            conversation.updatedAt = .now
                        }
                        typewriter.start(messageID: streamingMsg.id)
                    }

                    typewriter.feed(accumulatedText)

                case .completed(let text, let usage):
                    activeToolName = nil
                    let finalText = text.isEmpty ? accumulatedText : text
                    streamingMsg.content = finalText
                    streamingMsg.isStreaming = false
                    if !accumulatedReasoning.isEmpty {
                        streamingMsg.reasoningContent = accumulatedReasoning
                    }
                    typewriter.finish(finalText: finalText)

                    let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                    let tokenCount = usage?.outputTokens
                    let metadata = ResponseMetadata(modelName: nil, tokenCount: tokenCount, durationMs: durationMs)
                    streamingMsg.metadataJSON = try? String(data: JSONEncoder().encode(metadata), encoding: .utf8)

                    isSending = false
                    try? modelContext.save()

                case .error(let errorMsg):
                    activeToolName = nil
                    typewriter.stop()
                    isSending = false
                    conversation.messages.removeAll { $0.id == streamingMsg.id }
                    modelContext.delete(streamingMsg)
                    let block = ErrorBlock(summary: errorMsg, technicalDetail: nil, isRetryable: true)
                    appendErrorMessage(block, to: conversation)
                    return true
                }
            }

            // Stream ended without explicit completed — ensure isSending is cleared
            isSending = false
            if !hasReceivedFirstDelta {
                modelContext.delete(streamingMsg)
            }

            return true

        } catch {
            typewriter.stop()
            // Do NOT set isSending = false here — if falling back to CLI,
            // the caller needs isSending to remain true so the thinking
            // indicator stays visible during the CLI request.
            Self.logger.warning("Streaming failed, falling back to CLI: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - CLI Fallback Path

    private func sendViaCLI(prompt: String, conversation: Conversation) async {
        do {
            let response = try await container.gatewayService.sendMessage(prompt, context: conversation)
            withAnimation(SableAnimation.enter(duration: SableAnimation.slow)) {
                isSending = false
                appendAssistantMessage(response, to: conversation)
            }
        } catch is CancellationError {
            let block = ErrorBlock(summary: "Request cancelled.", technicalDetail: nil, isRetryable: false)
            withAnimation(SableAnimation.enter(duration: SableAnimation.slow)) {
                isSending = false
                appendErrorMessage(block, to: conversation)
            }
        } catch let error as GatewayService.GatewayError {
            withAnimation(SableAnimation.enter(duration: SableAnimation.slow)) {
                isSending = false
                appendErrorMessage(error.asErrorBlock, to: conversation)
            }
        } catch {
            let block = ErrorBlock(
                summary: "Could not reach OpenClaw gateway.",
                technicalDetail: error.localizedDescription,
                isRetryable: true
            )
            withAnimation(SableAnimation.enter(duration: SableAnimation.slow)) {
                isSending = false
                appendErrorMessage(block, to: conversation)
            }
        }
    }

    // MARK: - Message Helpers

    private func appendAssistantMessage(
        _ response: ParsedAgentResponse,
        to conversation: Conversation
    ) {
        let msg = Message(
            role: .assistant,
            content: response.plainText,
            blocks: response.blocks.count > 1 ? response.blocks : nil,
            metadata: response.metadata
        )
        conversation.messages.append(msg)
        conversation.updatedAt = .now
        modelContext.insert(msg)
        try? modelContext.save()
    }

    private func appendErrorMessage(
        _ errorBlock: ErrorBlock,
        to conversation: Conversation
    ) {
        let msg = Message(
            role: .assistant,
            content: errorBlock.summary,
            isError: true,
            blocks: [.error(errorBlock)]
        )
        conversation.messages.append(msg)
        conversation.updatedAt = .now
        modelContext.insert(msg)
        try? modelContext.save()
    }

    // MARK: - Delete Message

    private func deleteMessage(_ message: Message, from conversation: Conversation) {
        conversation.messages.removeAll { $0.id == message.id }
        modelContext.delete(message)
        try? modelContext.save()
    }

    // MARK: - Regenerate

    private func regenerateLastResponse(in conversation: Conversation) {
        guard !isSending else { return }

        let sorted = conversation.messages.sorted { $0.createdAt < $1.createdAt }
        guard let lastReply = sorted.last(where: { $0.role == .assistant || $0.isError }) else { return }
        guard let lastReplyIndex = sorted.firstIndex(where: { $0.id == lastReply.id }),
              lastReplyIndex > 0 else { return }

        let userMessage = sorted[lastReplyIndex - 1]
        guard userMessage.role == .user else { return }

        let prompt = userMessage.content
        deleteMessage(lastReply, from: conversation)
        send(prompt: prompt, in: conversation, skipUserMessage: true)
    }

    // MARK: - Title Generation

    private func smartTitle(from text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count > 40 else { return cleaned }

        let prefix = String(cleaned.prefix(40))
        if let lastSpace = prefix.lastIndex(of: " ") {
            let truncated = String(prefix[prefix.startIndex..<lastSpace])
            return truncated.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces)) + "…"
        }
        return prefix + "…"
    }
}
