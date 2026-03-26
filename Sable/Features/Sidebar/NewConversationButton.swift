import SwiftUI

struct NewConversationButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(L10n.string("sidebar.newConversation", default: "New Chat"), systemImage: "square.and.pencil")
                .font(SableTypography.labelMedium)
                .foregroundStyle(.primary)
                .frame(width: SidebarLayoutMetrics.rowContentWidth, alignment: .leading)
                .padding(.horizontal, SidebarLayoutMetrics.rowHorizontalPadding)
                .padding(.vertical, SidebarLayoutMetrics.rowVerticalPadding)
                .frame(width: SidebarLayoutMetrics.rowOuterWidth, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: SidebarLayoutMetrics.rowCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(width: SidebarLayoutMetrics.rowOuterWidth, alignment: .leading)
    }
}
