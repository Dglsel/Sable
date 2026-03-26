import SwiftUI

struct MessageListView: View {
    let conversation: Conversation
    let isSending: Bool
    let activeToolName: String?
    let typewriter: TypewriterState
    var onDeleteMessage: ((Message) -> Void)?
    var onRegenerate: (() -> Void)?

    @State private var isNearBottom = true

    private var sortedMessages: [Message] {
        conversation.messages.sorted { $0.createdAt < $1.createdAt }
    }

    private var lastAssistantOrErrorID: UUID? {
        sortedMessages.last(where: { $0.role == .assistant || $0.isError })?.id
    }

    private var showThinkingIndicator: Bool {
        isSending && (activeToolName != nil || !conversation.messages.contains(where: { $0.isStreaming }))
    }

    private var showScrollButton: Bool {
        !isNearBottom && sortedMessages.count > 3
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ForEach(sortedMessages, id: \.id) { message in
                                MessageRowView(
                                    message: message,
                                    isLastAssistantOrError: message.id == lastAssistantOrErrorID,
                                    typewriterText: message.id == typewriter.activeMessageID
                                        ? typewriter.displayedText
                                        : nil,
                                    onDelete: { onDeleteMessage?(message) },
                                    onRegenerate: onRegenerate
                                )
                                .id(message.id)
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.animation(SableAnimation.enter()),
                                        removal: .opacity.animation(SableAnimation.exit(duration: SableAnimation.fast))
                                    )
                                )
                            }
                        }
                        .frame(maxWidth: AppLayoutMetrics.chatColumnMaxWidth)
                        .frame(maxWidth: .infinity)

                        // Thinking indicator — outside LazyVStack so it's always rendered
                        if showThinkingIndicator {
                            ThinkingIndicatorView(activeToolName: activeToolName)
                                .id("thinking-indicator")
                                .frame(maxWidth: AppLayoutMetrics.chatColumnMaxWidth)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                                .transition(
                                    .opacity
                                        .combined(with: .offset(y: 6))
                                        .animation(SableAnimation.enter(duration: SableAnimation.slow))
                                )
                        }

                        // Bottom anchor — outside LazyVStack so scrollTo always works
                        Color.clear
                            .frame(height: 1)
                            .id("bottom-anchor")
                            .onAppear { isNearBottom = true }
                            .onDisappear { isNearBottom = false }
                    }
                    .padding(.horizontal, SableSpacing.xLarge)
                    .padding(.vertical, SableSpacing.xLarge)
                }
                .scrollClipDisabled()
                .scrollIndicators(.never)
                .background(SableTheme.chatBackground)
                .onAppear {
                    scrollToBottom(with: proxy)
                }
                .onChange(of: sortedMessages.count) { _, _ in
                    if isNearBottom {
                        withAnimation(SableAnimation.enter(duration: SableAnimation.slow)) {
                            scrollToBottom(with: proxy)
                        }
                    }
                }
                .onChange(of: isSending) { _, sending in
                    if sending {
                        withAnimation(SableAnimation.enter(duration: SableAnimation.slow)) {
                            scrollToBottom(with: proxy)
                        }
                    }
                }
                .onChange(of: typewriter.displayedText) { _, _ in
                    if isNearBottom {
                        proxy.scrollTo("bottom-anchor", anchor: .bottom)
                    }
                }
                .onChange(of: typewriter.activeMessageID) { _, id in
                    if id != nil, isNearBottom {
                        proxy.scrollTo("bottom-anchor", anchor: .bottom)
                    }
                }

                // Scroll-to-bottom button
                if showScrollButton {
                    ScrollToBottomButton {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            scrollToBottom(with: proxy)
                        }
                    }
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)).combined(with: .offset(y: 8)))
                }
            }
            .animation(SableAnimation.move(duration: SableAnimation.fast), value: showScrollButton)
            .animation(SableAnimation.enter(duration: SableAnimation.fast), value: showThinkingIndicator)
            .id(conversation.id)
        }
    }

    private func scrollToBottom(with proxy: ScrollViewProxy) {
        proxy.scrollTo("bottom-anchor", anchor: .bottom)
    }
}

// MARK: - Scroll-to-Bottom Button

private struct ScrollToBottomButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SableTheme.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                )
                .overlay(
                    Circle()
                        .stroke(SableTheme.border, lineWidth: 0.5)
                )
                .scaleEffect(isHovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
    }
}
