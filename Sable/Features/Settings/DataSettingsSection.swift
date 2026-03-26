import SwiftData
import SwiftUI

struct DataSettingsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query private var appSettings: [AppSettings]
    @Query private var providerSettings: [ProviderSettings]
    @Query private var conversations: [Conversation]

    var body: some View {
        SettingsSectionContainer(title: L10n.string("settings.data.title", default: "Data")) {
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "trash",
                    iconColor: SableTheme.error,
                    title: L10n.string("settings.data.clearHistory", default: "Clear History")
                ) {
                    Button(role: .destructive) {
                        clearHistory()
                    } label: {
                        Text(L10n.string("settings.data.clearHistory", default: "Clear History"))
                            .font(SableTypography.labelSmall)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                SettingsDivider()

                SettingsRow(
                    icon: "arrow.counterclockwise",
                    iconColor: .gray,
                    title: L10n.string("settings.data.resetSettings", default: "Reset Settings")
                ) {
                    Button {
                        resetSettings()
                    } label: {
                        Text(L10n.string("settings.data.resetSettings", default: "Reset Settings"))
                            .font(SableTypography.labelSmall)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func clearHistory() {
        conversations.forEach(modelContext.delete)
        appState.selectedConversationID = nil
        try? modelContext.save()
    }

    private func resetSettings() {
        if let settings = appSettings.first {
            settings.interfaceLanguage = .followSystem
            settings.appearanceMode = .light
            settings.launchBehavior = .reopenLastConversation
            appState.sync(with: settings)
        }

        providerSettings.forEach { setting in
            if let definition = ProviderRegistry.all.first(where: { $0.kind == setting.provider }) {
                setting.isEnabled = setting.provider == .openAI || setting.provider == .anthropic || setting.provider == .gemini
                setting.baseURL = definition.defaultBaseURL
                setting.defaultModel = definition.defaultModel
            }
        }

        try? modelContext.save()
    }
}
