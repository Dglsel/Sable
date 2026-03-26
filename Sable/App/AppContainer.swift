import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppContainer {
    let persistenceController: PersistenceController
    let keychainService: KeychainService
    let providerRegistry: ProviderRegistry
    let providerModelDiscoveryService: ProviderModelDiscoveryService
    let openClawService: OpenClawService
    let gatewayService: GatewayService
    let appState: AppState

    init(inMemory: Bool = false) {
        persistenceController = PersistenceController(inMemory: inMemory)
        keychainService = KeychainService()
        providerModelDiscoveryService = ProviderModelDiscoveryService()
        openClawService = OpenClawService()
        gatewayService = GatewayService(openClawService: openClawService)
        providerRegistry = ProviderRegistry(
            providers: [
                MockProvider(),
                OpenAIProvider(
                    configurationResolver: Self.openAIConfigurationResolver(
                        providerConfigurationResolver: Self.providerConfigurationResolver(
                            for: .openAI,
                            defaultBaseURL: OpenAIProvider.defaultBaseURL,
                            defaultModel: OpenAIProvider.defaultModel,
                            persistenceController: persistenceController,
                            keychainService: keychainService
                        )
                    )
                ),
                AnthropicProvider(
                    configurationResolver: Self.providerConfigurationResolver(
                        for: .anthropic,
                        defaultBaseURL: AnthropicProvider.defaultBaseURL,
                        defaultModel: AnthropicProvider.defaultModel,
                        persistenceController: persistenceController,
                        keychainService: keychainService
                    )
                ),
                GeminiProvider(
                    configurationResolver: Self.providerConfigurationResolver(
                        for: .gemini,
                        defaultBaseURL: GeminiProvider.defaultBaseURL,
                        defaultModel: GeminiProvider.defaultModel,
                        persistenceController: persistenceController,
                        keychainService: keychainService
                    )
                )
            ]
        )

        let context = ModelContext(persistenceController.modelContainer)
        MockSeedService.seedIfNeeded(in: context)

        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let conversationDescriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\Conversation.updatedAt, order: .reverse)]
        )
        let settings = (try? context.fetch(settingsDescriptor).first) ?? AppSettings()
        let latestConversation = try? context.fetch(conversationDescriptor).first
        appState = AppState(settings: settings, selectedConversationID: latestConversation?.id)

        startConnectionStatusSync()
    }

    /// Keeps `appState.connectionStatus` and `appState.toolbarModelLabel` in sync
    /// with `openClawService.status`. Runs independently of window lifecycle so all
    /// windows (including MenuBar) stay current without a restart.
    private func startConnectionStatusSync() {
        syncConnectionStatus()
    }

    private func syncConnectionStatus() {
        withObservationTracking {
            let status = openClawService.status
            appState.connectionStatus = .from(status)
            // Refresh model label whenever OpenClaw transitions to running,
            // so a config-file model change is reflected without restart.
            if case .running = status {
                refreshModelLabel()
            }
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.syncConnectionStatus()
            }
        }
    }

    /// Reads the current primary model from disk and updates the toolbar label.
    /// Called at app start (via AppScene.onAppear) and on every status→running transition.
    func refreshModelLabel() {
        let config = OpenClawConfig.readFromDisk()
        guard let model = config.primaryModel, !model.isEmpty else { return }
        appState.toolbarModelLabel = Self.shortenModelName(model)
    }

    /// Converts a raw model ID (e.g. `anthropic/claude-sonnet-4-6`) to a short
    /// toolbar display name (e.g. `Claude Sonnet 4.6`).
    static func shortenModelName(_ fullID: String) -> String {
        let raw = fullID.contains("/")
            ? String(fullID.split(separator: "/").last ?? Substring(fullID))
            : fullID

        var parts = raw.split(separator: "-").map(String.init)

        // Drop trailing date stamps like "20251101" (8-digit all-numeric)
        parts = parts.filter { !($0.count == 8 && $0.allSatisfy(\.isNumber)) }

        // Drop trailing build-tag suffixes (5+ digits) but keep short version numbers
        while let last = parts.last, last.allSatisfy(\.isNumber), last.count >= 5 {
            parts.removeLast()
        }

        // GPT models keep the hyphen: "gpt-4.1" → "GPT-4.1"
        if parts.first?.lowercased() == "gpt" {
            return "GPT-\(parts.dropFirst().joined(separator: "-"))"
        }

        return parts.map { part -> String in
            if part.first?.isNumber == true { return part }
            if part.count <= 5 && part.contains(where: \.isNumber) { return part.uppercased() }
            return part.capitalized
        }.joined(separator: " ")
    }

    private static func openAIConfigurationResolver(
        providerConfigurationResolver: @escaping @MainActor @Sendable () -> ProviderRuntimeConfiguration
    ) -> OpenAIProvider.ConfigurationResolver {
        {
            OpenAIProvider.Configuration(snapshot: providerConfigurationResolver())
        }
    }

    private static func providerConfigurationResolver(
        for providerKind: ProviderKind,
        defaultBaseURL: String,
        defaultModel: String,
        persistenceController: PersistenceController,
        keychainService: KeychainService
    ) -> @MainActor @Sendable () -> ProviderRuntimeConfiguration {
        { @MainActor in
            let context = ModelContext(persistenceController.modelContainer)
            let settings = ((try? context.fetch(FetchDescriptor<ProviderSettings>())) ?? [])
                .first(where: { $0.provider == providerKind })

            let apiKeyReference = settings?.apiKeyReference ?? ""
            let apiKey = (keychainService.read(account: apiKeyReference) ?? "").removingWhitespaceAndNewlines
            let configuredBaseURL = settings?.baseURL.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let configuredModel = settings?.defaultModel.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return ProviderRuntimeConfiguration(
                isEnabled: settings?.isEnabled ?? false,
                apiKey: apiKey,
                baseURL: configuredBaseURL.isEmpty ? defaultBaseURL : configuredBaseURL,
                model: configuredModel.isEmpty ? defaultModel : configuredModel
            )
        }
    }
}
