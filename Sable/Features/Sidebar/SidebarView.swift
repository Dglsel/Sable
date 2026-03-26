import SwiftUI

struct SidebarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @Environment(OpenClawService.self) private var openClaw

    let conversations: [Conversation]
    @Binding var selectedConversationID: UUID?
    let onNewConversation: () -> Void

    private var isReady: Bool {
        openClaw.status.isOnboarded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: SidebarLayoutMetrics.sectionSpacing) {
                // Navigation pages
                navigationSection

                Divider()

                if isReady {
                    SidebarSectionHeader(title: L10n.string("sidebar.recentConversations", default: "Recent"))
                        .padding(.top, 4)

                    historyList
                        .frame(width: SidebarLayoutMetrics.scrollContainerWidth, alignment: .leading)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                } else {
                    Spacer()
                }

                Divider()

                // Bottom: settings
                bottomSection
            }
            .frame(width: SidebarLayoutMetrics.rowOuterWidth, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, SidebarLayoutMetrics.contentHorizontalPadding)
            .padding(.bottom, SableSpacing.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, SableSpacing.medium)
        .background(SableTheme.sidebarBackground(colorScheme))
    }

    // MARK: - Navigation

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SidebarPage.allCases) { page in
                sidebarNavButton(page: page)
            }
        }
    }

    private func sidebarNavButton(page: SidebarPage) -> some View {
        Button {
            appState.activePage = page
        } label: {
            HStack(spacing: 8) {
                Image(systemName: page.icon)
                    .font(.system(size: 11.5))
                    .foregroundStyle(appState.activePage == page ? .primary : .secondary)
                    .frame(width: 18)
                Text(page.label)
                    .font(SableTypography.labelSmall)
                    .foregroundStyle(appState.activePage == page ? .primary : .secondary)
                Spacer()
                if page == .dashboard {
                    statusDot
                }
            }
            .padding(.vertical, SidebarLayoutMetrics.rowVerticalPadding)
            .padding(.horizontal, SidebarLayoutMetrics.rowHorizontalPadding)
            .background(
                appState.activePage == page
                    ? SableTheme.bgActive
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: SidebarLayoutMetrics.rowCornerRadius)
            )
            .contentShape(RoundedRectangle(cornerRadius: SidebarLayoutMetrics.rowCornerRadius))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    @ViewBuilder
    private var statusDot: some View {
        Circle()
            .fill(openClawStatusColor)
            .frame(width: 5, height: 5)
            .opacity(0.8)
    }

    private var openClawStatusColor: Color {
        switch openClaw.status {
        case .notInstalled: SableTheme.textSecondary
        case .needsOnboarding: SableTheme.warning
        case .installedStopped: SableTheme.warning
        case .running: SableTheme.success
        case .error: SableTheme.error
        }
    }

    // MARK: - History List

    private var historyList: some View {
        ScrollView(showsIndicators: false) {
            historyListContent
        }
        .compositingGroup()
        .clipped()
    }

    private var historyListContent: some View {
        VStack(alignment: .leading, spacing: SidebarLayoutMetrics.rowSpacing) {
            ForEach(conversations, id: \.id) { conversation in
                SidebarConversationButton(
                    conversation: conversation,
                    isSelected: appState.activePage == .chat && selectedConversationID == conversation.id
                ) {
                    selectedConversationID = conversation.id
                    appState.activePage = .chat
                } onDelete: {
                    deleteConversation(conversation)
                }
            }
        }
        .frame(width: SidebarLayoutMetrics.scrollContainerWidth, alignment: .leading)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    // MARK: - Actions

    private func deleteConversation(_ conversation: Conversation) {
        let wasSelected = selectedConversationID == conversation.id
        modelContext.delete(conversation)
        try? modelContext.save()

        if wasSelected {
            // Select the next available conversation
            let remaining = conversations.filter { $0.id != conversation.id }
            selectedConversationID = remaining.first?.id
        }
    }

    // MARK: - Bottom

    private var bottomSection: some View {
        HStack {
            Button {
                openWindow(id: WindowNavigator.settingsWindowID)
            } label: {
                Label {
                    Text(L10n.string("settings.title", default: "Settings"))
                        .font(SableTypography.labelSmall)
                } icon: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 2)
        .padding(.horizontal, SidebarLayoutMetrics.rowHorizontalPadding)
    }
}
