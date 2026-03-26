import SwiftUI

/// Settings section that displays OpenClaw model and provider configuration.
/// All data is read from `~/.openclaw/openclaw.json` — the single source of truth.
struct ModelsSettingsSection: View {
    @Environment(AppState.self) private var appState
    @State private var config = OpenClawConfig.readFromDisk()
    @State private var selectedModel: String = ""
    @State private var saveStatus: SaveStatus = .idle

    private enum SaveStatus: Equatable {
        case idle
        case saved
        case error(String)
    }

    /// Whether OpenClaw has been set up (config file exists with auth or models).
    private var isReady: Bool {
        !config.authProfiles.isEmpty || !config.configuredModels.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SableSpacing.xLarge) {
            if isReady {
                readyContent
            } else {
                notReadyContent
            }
        }
        .onAppear {
            config = OpenClawConfig.readFromDisk()
            selectedModel = config.primaryModel ?? ""
        }
    }

    // MARK: - Not Ready State

    private var notReadyContent: some View {
        SettingsSectionContainer(title: "Models & Providers") {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)

                    Text("OpenClaw Setup Required")
                        .font(SableTypography.subtitle)

                    Text("Complete setup on the Dashboard to view and manage configured models.")
                        .font(SableTypography.labelSmall)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }

                Button {
                    appState.activePage = .dashboard
                    WindowNavigator.activateMainWindow()
                } label: {
                    Label("Go to Dashboard", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Ready State

    private var readyContent: some View {
        Group {
            primaryModelSection
            configuredModelsSection
            authProvidersSection
            terminalHint
        }
    }

    // MARK: - Primary Model

    private var primaryModelSection: some View {
        SettingsSectionContainer(title: "Primary Model") {
            SettingsRow(
                icon: "cpu",
                iconColor: SableTheme.info,
                title: "Active Model"
            ) {
                HStack(spacing: 8) {
                    if config.configuredModels.count > 1 {
                        Picker("", selection: $selectedModel) {
                            ForEach(config.configuredModels, id: \.self) { model in
                                Text(displayName(for: model)).tag(model)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                        .onChange(of: selectedModel) { _, newValue in
                            guard !newValue.isEmpty,
                                  newValue != config.primaryModel else { return }
                            if let updated = OpenClawConfig.writePrimaryModel(newValue) {
                                config = updated
                                showSaved()
                            } else {
                                saveStatus = .error("Failed to write config")
                            }
                        }
                    } else {
                        Text(displayName(for: config.primaryModel ?? ""))
                            .font(SableTypography.codeInline)
                            .foregroundStyle(.secondary)
                    }

                    saveStatusView
                }
            }
        }
    }

    // MARK: - Configured Models

    private var configuredModelsSection: some View {
        SettingsSectionContainer(title: "Configured Models") {
            VStack(spacing: 0) {
                ForEach(Array(config.configuredModels.enumerated()), id: \.element) { index, model in
                    if index > 0 { SettingsDivider() }
                    modelRow(model)
                }
            }
        }
    }

    private func modelRow(_ modelID: String) -> some View {
        let parts = modelID.split(separator: "/", maxSplits: 1)
        let provider = parts.first.map(String.init) ?? modelID
        let model = parts.count > 1 ? String(parts[1]) : ""
        let isPrimary = modelID == config.primaryModel

        return HStack(spacing: 12) {
            Image(systemName: isPrimary ? "star.fill" : "cube")
                .font(.system(size: 13))
                .foregroundStyle(isPrimary ? SableTheme.warning : .secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(model.isEmpty ? modelID : model)
                        .font(SableTypography.body)
                    if isPrimary {
                        Text("Primary")
                            .font(.system(size: 9, weight: .semibold)) // badge label — intentionally tiny
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(SableTheme.interactive, in: Capsule())
                    }
                }
                if !provider.isEmpty && !model.isEmpty {
                    Text(provider)
                        .font(SableTypography.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Auth Providers

    private var authProvidersSection: some View {
        SettingsSectionContainer(title: "Authenticated Providers") {
            VStack(spacing: 0) {
                ForEach(Array(config.authProfiles.enumerated()), id: \.element.id) { index, profile in
                    if index > 0 { SettingsDivider() }
                    providerRow(profile)
                }
            }
        }
    }

    private func providerRow(_ profile: OpenClawConfig.AuthProfile) -> some View {
        SettingsRow(
            icon: "checkmark.shield",
            iconColor: SableTheme.success,
            title: profile.provider
        ) {
            Text(profile.mode)
                .font(SableTypography.codeLabel)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Terminal Hint

    private var terminalHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "terminal")
                .font(.system(size: 11))
            Text("To add models or change providers, run ")
                + Text("openclaw onboard").font(SableTypography.mono)
                + Text(" in Terminal.")
        }
        .font(SableTypography.caption)
        .foregroundStyle(.tertiary)
        .padding(.leading, 4)
    }

    // MARK: - Helpers

    /// Extracts a short display name from a full model ID like "openai-codex/gpt-5.4".
    private func displayName(for modelID: String) -> String {
        let parts = modelID.split(separator: "/", maxSplits: 1)
        if parts.count > 1 {
            return String(parts[1])
        }
        return modelID
    }

    private func showSaved() {
        saveStatus = .saved
        Task {
            try? await Task.sleep(for: .seconds(2))
            if saveStatus == .saved { saveStatus = .idle }
        }
    }

    @ViewBuilder
    private var saveStatusView: some View {
        switch saveStatus {
        case .idle:
            EmptyView()
        case .saved:
            Label("Saved", systemImage: "checkmark")
                .font(SableTypography.caption)
                .foregroundStyle(SableTheme.success)
                .transition(.opacity)
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .font(SableTypography.caption)
                .foregroundStyle(SableTheme.error)
                .transition(.opacity)
        }
    }
}
