import SwiftUI

// MARK: - MessageRowView

struct MessageRowView: View {
    let message: Message
    let isLastAssistantOrError: Bool
    /// Non-nil only for the actively streaming message. Drives typewriter display.
    var typewriterText: String?
    var onDelete: (() -> Void)?
    var onRegenerate: (() -> Void)?

    @State private var isHovering = false
    @State private var hasAppeared = false

    private var isUserMessage: Bool { message.role == .user && !message.isError }

    private var shouldAnimateEntrance: Bool {
        Date.now.timeIntervalSince(message.createdAt) < 2
    }

    private var entranceOffsetX: CGFloat { isUserMessage ? 16 : 0 }
    private var entranceOffsetY: CGFloat { isUserMessage ? 0 : 12 }

    /// The text to display — typewriter-driven while streaming, full content otherwise.
    private var visibleText: String {
        typewriterText ?? message.content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            messageLayout
                .contextMenu { contextMenu }

            if !isUserMessage, !message.isError, !message.isStreaming,
               let metadata = message.responseMetadata {
                MessageStatusView(metadata: metadata)
                    .padding(.top, 2)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(x: hasAppeared ? 0 : entranceOffsetX,
                y: hasAppeared ? 0 : entranceOffsetY)
        .overlay(alignment: isUserMessage ? .bottomTrailing : .bottomLeading) {
            if !message.isStreaming {
                MessageActionBar(
                    message: message,
                    isLastAssistantOrError: isLastAssistantOrError,
                    onCopy: { copyContent() },
                    onRegenerate: onRegenerate,
                    onDelete: onDelete
                )
                .offset(y: 20)
                .opacity(isHovering ? 1 : (isLastAssistantOrError && !isUserMessage ? 0.35 : 0))
                .animation(SableAnimation.enter(duration: SableAnimation.fast), value: isHovering)
            }
        }
        .zIndex(isHovering ? 1 : 0)
        .onHover { isHovering = $0 }
        .onAppear {
            guard shouldAnimateEntrance else { hasAppeared = true; return }
            if isUserMessage {
                withAnimation(SableAnimation.springBouncy) {
                    hasAppeared = true
                }
            } else {
                withAnimation(SableAnimation.enter(duration: SableAnimation.entrance)) {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private var messageLayout: some View {
        if message.isError {
            errorLayout
        } else if message.role == .assistant {
            assistantLayout
        } else {
            userLayout
        }
    }

    private var assistantLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(SableTheme.interactive)
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                if let reasoning = message.reasoningContent, !reasoning.isEmpty, typewriterText == nil {
                    ThinkingBlockView(content: reasoning)
                }

                if typewriterText != nil {
                    // Streaming: show typewriter-driven plain text
                    TextBlockView(text: visibleText, role: .assistant, isError: false)
                } else {
                    // Complete: full markdown/code block rendering
                    MessageContentView(message: message)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var userLayout: some View {
        HStack {
            Spacer(minLength: 0)
            MessageContentView(message: message)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var errorLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(SableTheme.error)
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                MessageContentView(message: message, onRetry: onRegenerate)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenu: some View {
        Button { copyContent() } label: {
            Label("Copy Message", systemImage: "doc.on.doc")
        }
        if isLastAssistantOrError && (message.role == .assistant || message.isError) {
            Button { onRegenerate?() } label: {
                Label("Regenerate Response", systemImage: "arrow.clockwise")
            }
        }
        Divider()
        Button(role: .destructive) { onDelete?() } label: {
            Label("Delete Message", systemImage: "trash")
        }
    }

    private func copyContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
    }
}

// MARK: - Backward Compatibility

typealias MessageBubbleView = MessageRowView
