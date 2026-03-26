import SwiftUI

/// Inline action bar displayed below a message.
/// Shows Copy, Regenerate (conditional on last assistant/error), and Delete as flat icon buttons.
struct MessageActionBar: View {
    let message: Message
    let isLastAssistantOrError: Bool
    var onCopy: (() -> Void)?
    var onRegenerate: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 1) {
            ActionBarButton(icon: "doc.on.doc", help: "Copy") {
                onCopy?()
            }

            if isLastAssistantOrError && (message.role == .assistant || message.isError) {
                ActionBarButton(icon: "arrow.clockwise", help: "Regenerate") {
                    onRegenerate?()
                }
            }

            ActionBarButton(icon: "trash", help: "Delete") {
                onDelete?()
            }
        }
        .padding(.leading, message.role == .user ? 0 : 34)
    }
}

// MARK: - Action Bar Button (hover-aware)

struct ActionBarButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                .frame(width: 24, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: SableRadius.sm, style: .continuous)
                        .fill(isHovered ? SableTheme.bgHover : .clear)
                )
                .contentShape(Rectangle())
                .animation(SableAnimation.move(duration: SableAnimation.fast), value: isHovered)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
    }
}
