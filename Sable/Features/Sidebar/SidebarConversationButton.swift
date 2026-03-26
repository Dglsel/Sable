import SwiftUI

struct SidebarConversationButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let conversation: Conversation
    let isSelected: Bool
    let action: () -> Void
    var onDelete: (() -> Void)?

    @State private var isHovered = false
    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: action) {
            ConversationRowView(
                conversation: conversation,
                isSelected: isSelected,
                isHovered: isHovered,
                onDelete: { showDeleteConfirm = true }
            )
            .padding(.horizontal, SidebarLayoutMetrics.rowHorizontalPadding)
            .padding(.vertical, SidebarLayoutMetrics.rowVerticalPadding)
            .frame(width: SidebarLayoutMetrics.rowOuterWidth, alignment: .leading)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: SidebarLayoutMetrics.rowCornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: SidebarLayoutMetrics.rowCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .frame(width: SidebarLayoutMetrics.rowOuterWidth, alignment: .leading)
        .onHover { hovering in
            withAnimation(SableAnimation.move(duration: SableAnimation.fast)) {
                isHovered = hovering
            }
        }
        .alert("Delete Conversation?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                withAnimation(SableAnimation.enter()) {
                    onDelete?()
                }
            }
        } message: {
            Text("\"\(conversation.title)\" will be permanently deleted.")
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return SableTheme.bgActive
        }
        if isHovered {
            return SableTheme.bgHover
        }
        return Color.clear
    }
}
