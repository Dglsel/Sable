import AppKit
import SwiftData
import SwiftUI

struct MenuBarPanelView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    var body: some View {
        VStack(alignment: .leading, spacing: SableSpacing.medium) {
            Button(L10n.string("menubar.openMainWindow", default: "Open Main Window")) {
                openWindow(id: WindowNavigator.mainWindowID)
                WindowNavigator.activateApp()
            }

            Button(L10n.string("menubar.newConversation", default: "New Conversation")) {
                createConversation()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.string("menubar.connectionStatus", default: "Connection Status"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(
                    L10n.string(appState.connectionStatus.localizationKey, default: appState.connectionStatus.defaultTitle),
                    systemImage: "circle.fill"
                )
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(appState.connectionStatus.isOnline ? SableTheme.success : .secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("menubar.recentConversations", default: "Recent Conversations"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(conversations.prefix(3)), id: \.id) { conversation in
                    Button(conversation.title) {
                        appState.selectedConversationID = conversation.id
                        openWindow(id: WindowNavigator.mainWindowID)
                        WindowNavigator.activateApp()
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Button {
                openWindow(id: WindowNavigator.settingsWindowID)
            } label: {
                Label(L10n.string("settings.title", default: "Settings"), systemImage: "gearshape")
            }

            Button(L10n.string("menubar.quit", default: "Quit")) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(SableSpacing.large)
        .frame(width: 280)
    }

    private func createConversation() {
        let conversation = Conversation(title: L10n.string("sidebar.newConversation", default: "New Chat"))
        modelContext.insert(conversation)
        appState.selectedConversationID = conversation.id
        try? modelContext.save()
        openWindow(id: WindowNavigator.mainWindowID)
        WindowNavigator.activateApp()
    }
}
