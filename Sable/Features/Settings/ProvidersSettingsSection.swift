import SwiftUI

struct ProvidersSettingsSection: View {
    @Environment(AppContainer.self) private var container

    let providerSettings: [ProviderSettings]

    var body: some View {
        SettingsSectionContainer(title: L10n.string("settings.providers.title", default: "Providers")) {
            VStack(spacing: 0) {
                let sorted = providerSettings.sorted(by: { $0.provider.displayName < $1.provider.displayName })
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, setting in
                    ProviderCard(
                        setting: setting,
                        keychainService: container.keychainService,
                        providerRegistry: container.providerRegistry,
                        modelDiscoveryService: container.providerModelDiscoveryService
                    )

                    if index < sorted.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
    }
}

private struct ProviderCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    let setting: ProviderSettings
    let keychainService: KeychainService
    let providerRegistry: ProviderRegistry
    let modelDiscoveryService: ProviderModelDiscoveryService

    @State private var draft: ProviderSettingsDraft
    @State private var saveStatus: ProviderSettingsSaveStatus = .idle
    @State private var discoveredModels: [String] = []
    @State private var modelRefreshStatus: ProviderModelRefreshStatus = .idle
    @State private var refreshTask: Task<Void, Never>?
    @State private var autoSaveTask: Task<Void, Never>?

    init(
        setting: ProviderSettings,
        keychainService: KeychainService,
        providerRegistry: ProviderRegistry,
        modelDiscoveryService: ProviderModelDiscoveryService
    ) {
        self.setting = setting
        self.keychainService = keychainService
        self.providerRegistry = providerRegistry
        self.modelDiscoveryService = modelDiscoveryService
        _draft = State(
            initialValue: ProviderSettingsDraft(
                setting: setting,
                apiKey: keychainService.read(account: setting.apiKeyReference) ?? ""
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SableSpacing.small) {
            HStack {
                Text(setting.provider.displayName)
                    .font(SableTypography.title)
                Spacer()

                if modelRefreshStatus.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                if let message = statusMessage {
                    statusIndicator(message: message)
                }

                Toggle("", isOn: $draft.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }

            if setting.provider.requiresAPIKey {
                SecureField(L10n.string("settings.providers.apiKey", default: "API Key"), text: $draft.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(SableTypography.labelSmall)
            }

            TextField(L10n.string("settings.providers.baseURL", default: "Base URL"), text: $draft.baseURL)
                .textFieldStyle(.roundedBorder)
                .font(SableTypography.labelSmall)

            ProviderModelPickerField(
                provider: setting.provider,
                draft: $draft,
                discoveredModels: discoveredModels,
                isReady: isModelSelectionReady
            )
        }
        .padding(12)
        .onChange(of: draft) { oldValue, newValue in
            guard oldValue != newValue else { return }

            let credentialsChanged = oldValue.isEnabled != newValue.isEnabled
                || oldValue.normalizedAPIKey != newValue.normalizedAPIKey
                || oldValue.trimmedBaseURL != newValue.trimmedBaseURL

            let modelChanged = oldValue.trimmedDefaultModel != newValue.trimmedDefaultModel

            if credentialsChanged {
                discoveredModels = []
                refreshTask?.cancel()
                refreshTask = nil
                scheduleAutoSaveAndRefresh()
            } else if modelChanged {
                fullSave()
            }
        }
        .onAppear {
            if discoveredModels.isEmpty && isModelSelectionReady {
                refreshModels()
            }
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
            autoSaveTask?.cancel()
            autoSaveTask = nil
        }
    }

    /// Whether the provider has enough configuration to select/fetch models.
    /// Ollama doesn't require an API key, so `isModelSelectionEnabled` is too strict for it.
    private var isModelSelectionReady: Bool {
        if setting.provider.requiresAPIKey {
            return draft.isModelSelectionEnabled
        }
        return draft.isEnabled && draft.hasValidBaseURL
    }

    // MARK: - Status Display

    private var statusMessage: String? {
        if let message = modelRefreshStatus.message {
            return message
        }
        if let message = saveStatus.message {
            return message
        }
        return nil
    }

    private func statusIndicator(message: String) -> some View {
        let isError = saveStatus != .idle && !saveStatus.isSuccess
            || modelRefreshStatus != .idle && !modelRefreshStatus.isSuccess && !modelRefreshStatus.isLoading
        return HStack(spacing: 4) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(isError ? SableTheme.warning : SableTheme.success)
            Text(message)
                .font(SableTypography.caption)
                .foregroundStyle(.secondary)
        }
        .transition(.opacity)
    }

    // MARK: - Auto-Save & Refresh

    private func scheduleAutoSaveAndRefresh() {
        autoSaveTask?.cancel()
        saveStatus = .idle
        modelRefreshStatus = .idle

        autoSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            autoSaveCredentialsAndRefresh()
        }
    }

    private func autoSaveCredentialsAndRefresh() {
        let saver = ProviderSettingsSaver(saveAPIKey: persistAPIKey(_:for:))
        let persisted = saver.persistCredentials(
            draft: draft,
            for: setting,
            modelContext: modelContext
        )

        if persisted && isModelSelectionReady {
            saveStatus = .saved
            refreshModels()
        } else if persisted {
            saveStatus = .idle
        }
    }

    private func fullSave() {
        let saver = ProviderSettingsSaver(saveAPIKey: persistAPIKey(_:for:))
        let status = saver.save(
            draft: draft,
            for: setting,
            modelContext: modelContext
        )

        if status.isSuccess {
            draft = ProviderSettingsDraft(setting: setting, apiKey: draft.normalizedAPIKey)
        }

        saveStatus = status
    }

    private func refreshModels() {
        guard isModelSelectionReady else {
            discoveredModels = []
            modelRefreshStatus = .idle
            return
        }

        let provider = setting.provider
        let apiKey = draft.normalizedAPIKey
        let baseURL = draft.trimmedBaseURL

        refreshTask?.cancel()
        modelRefreshStatus = .loading

        refreshTask = Task { @MainActor in
            do {
                let models = try await modelDiscoveryService.fetchModels(
                    for: provider,
                    apiKey: apiKey,
                    baseURL: baseURL
                )

                discoveredModels = models
                if draft.trimmedDefaultModel.isEmpty, let firstModel = models.first {
                    draft.defaultModel = firstModel
                }
                modelRefreshStatus = .refreshed
            } catch is CancellationError {
                modelRefreshStatus = .idle
            } catch {
                modelRefreshStatus = .failure(
                    providerErrorMessage(
                        from: error,
                        fallback: L10n.string(
                            "settings.providers.error.modelRefreshFailed",
                            default: "Could not refresh models."
                        )
                    )
                )
            }

            refreshTask = nil
        }
    }

    private func persistAPIKey(_ value: String, for account: String) {
        let normalizedValue = value.removingWhitespaceAndNewlines

        if normalizedValue.isEmpty {
            keychainService.delete(account: account)
        } else {
            keychainService.save(normalizedValue, for: account)
        }
    }

    private func providerErrorMessage(from error: Error, fallback: String) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !localized.isEmpty {
            return localized
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? fallback : description
    }
}

private struct ProviderModelPickerField: View {
    let provider: ProviderKind
    @Binding var draft: ProviderSettingsDraft
    let discoveredModels: [String]
    let isReady: Bool

    private var selection: Binding<String> {
        Binding(
            get: { draft.trimmedDefaultModel },
            set: { draft.defaultModel = $0 }
        )
    }

    private var modelOptions: [String] {
        ProviderModelCatalog.modelOptions(
            for: provider,
            currentSelection: draft.defaultModel,
            preferredModels: discoveredModels
        )
    }

    private var disabledModelText: String {
        let currentValue = draft.trimmedDefaultModel
        if !currentValue.isEmpty {
            return currentValue
        }

        return L10n.string(
            "settings.providers.modelPicker.disabled",
            default: "Enable this provider, add an API Key, and set a valid Base URL to choose a model."
        )
    }

    var body: some View {
        if isReady {
            Picker(
                L10n.string("settings.providers.modelPicker.placeholder", default: "Select a model"),
                selection: selection
            ) {
                Text(L10n.string("settings.providers.modelPicker.placeholder", default: "Select a model"))
                    .tag("")

                ForEach(modelOptions, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .pickerStyle(.menu)
        } else {
            TextField(
                L10n.string("settings.providers.defaultModel", default: "Default Model"),
                text: .constant(disabledModelText)
            )
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12))
            .disabled(true)
            .opacity(0.5)
        }
    }
}

private enum ProviderModelRefreshStatus: Equatable {
    case idle
    case loading
    case refreshed
    case failure(String)

    var message: String? {
        switch self {
        case .idle, .loading:
            nil
        case .refreshed:
            L10n.string("settings.providers.modelsRefreshed", default: "Models updated")
        case .failure(let message):
            message
        }
    }

    var isLoading: Bool {
        if case .loading = self {
            return true
        }

        return false
    }

    var isSuccess: Bool {
        if case .refreshed = self {
            return true
        }

        return false
    }
}

