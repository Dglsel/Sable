import SwiftData
import SwiftUI

struct AppScene: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(OpenClawService.self) private var openClaw
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    @State private var sidebarContentVisible = true

    private var sidebarWidth: CGFloat {
        AppLayoutMetrics.sidebarIdealWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                conversations: conversations,
                selectedConversationID: Binding(
                    get: { appState.selectedConversationID },
                    set: { newID in
                        appState.selectedConversationID = newID
                        appState.activePage = .chat
                    }
                ),
                onNewConversation: createConversation
            )
            .frame(width: sidebarWidth)
            .opacity(sidebarContentVisible ? 1 : 0)
            .frame(width: appState.isSidebarOpen ? sidebarWidth : 0, alignment: .leading)
            .clipped()
            .allowsHitTesting(appState.isSidebarOpen)

            Divider()
                .opacity(appState.isSidebarOpen ? 1 : 0)

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 860, minHeight: 600)
        .background(SableTheme.chatBackground)
        .navigationTitle("")
        .onAppear {
            ensureSelection()
            container.refreshModelLabel()
        }
        .onChange(of: conversations.count) { _, _ in
            ensureSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clawHubNewChat)) { _ in
            createConversation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clawHubOpenSettings)) { _ in
            openWindow(id: WindowNavigator.settingsWindowID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .clawHubToggleSidebar)) { _ in
            toggleSidebar()
        }
        .id(appState.interfaceLanguage)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch appState.activePage {
        case .dashboard:
            DashboardView()
        case .agents:
            AgentsView()
        case .skills:
            SkillsView()
        case .chat:
            ChatHomeView(
                conversation: selectedConversation,
                onCreateConversation: createConversation
            )
        }
    }

    // MARK: - Conversation Management

    private var selectedConversation: Conversation? {
        if let selectedConversationID = appState.selectedConversationID,
           let selectedConversation = conversations.first(where: { $0.id == selectedConversationID }) {
            return selectedConversation
        }
        return conversations.first
    }

    private func ensureSelection() {
        guard let firstConversation = conversations.first else {
            appState.selectedConversationID = nil
            return
        }
        if selectedConversation == nil {
            appState.selectedConversationID = firstConversation.id
        }
    }

    private func createConversation() {
        let conversation = Conversation(title: L10n.string("sidebar.newConversation", default: "New Chat"))
        modelContext.insert(conversation)
        appState.selectedConversationID = conversation.id
        appState.activePage = .chat
        try? modelContext.save()
    }

    // MARK: - Sidebar Toggle (two-phase animation)

    private func toggleSidebar() {
        if appState.isSidebarOpen {
            withAnimation(SableAnimation.exit(duration: SableAnimation.micro)) {
                sidebarContentVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) {
                    appState.isSidebarOpen = false
                }
            }
        } else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) {
                appState.isSidebarOpen = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(SableAnimation.enter(duration: SableAnimation.fast)) {
                    sidebarContentVisible = true
                }
            }
        }
    }

}
