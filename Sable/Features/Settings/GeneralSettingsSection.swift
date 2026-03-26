import SwiftUI

struct GeneralSettingsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var settings: AppSettings

    var body: some View {
        SettingsSectionContainer(title: L10n.string("settings.general.title", default: "General")) {
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "globe",
                    iconColor: SableTheme.info,
                    title: L10n.string("settings.general.interfaceLanguage", default: "Interface Language")
                ) {
                    Picker("", selection: Binding(
                        get: { settings.interfaceLanguage },
                        set: {
                            settings.interfaceLanguage = $0
                            appState.interfaceLanguage = $0
                            L10n.currentLanguage = $0
                        }
                    )) {
                        ForEach(InterfaceLanguage.allCases) { language in
                            Text(L10n.string(language.localizationKey, default: language.displayTitle)).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }

                SettingsDivider()

                SettingsRow(
                    icon: "circle.lefthalf.filled",
                    iconColor: SableTheme.info,
                    title: L10n.string("settings.general.appearance", default: "Appearance")
                ) {
                    Picker("", selection: Binding(
                        get: { settings.appearanceMode },
                        set: { newValue in
                            settings.appearanceMode = newValue
                            appState.appearanceMode = newValue
                            appState.applyAppearanceToAllWindows()
                        }
                    )) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(L10n.string(mode.localizationKey, default: mode.displayTitle)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }

                SettingsDivider()

                SettingsRow(
                    icon: "arrow.clockwise",
                    iconColor: SableTheme.warning,
                    title: L10n.string("settings.general.launchBehavior", default: "Launch Behavior")
                ) {
                    Picker("", selection: Binding(
                        get: { settings.launchBehavior },
                        set: { settings.launchBehavior = $0 }
                    )) {
                        ForEach(LaunchBehavior.allCases) { behavior in
                            Text(L10n.string(behavior.localizationKey, default: behavior.displayTitle)).tag(behavior)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
            }
        }
    }
}

// MARK: - Reusable Settings Components

struct SettingsSectionContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SableSpacing.small) {
            Text(title)
                .font(SableTypography.labelSmallMedium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            content
                .background(
                    RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous)
                        .fill(SableTheme.bgHover)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous)
                        .stroke(SableTheme.border)
                )
        }
    }
}

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(iconColor, in: RoundedRectangle(cornerRadius: SableRadius.md, style: .continuous))

            Text(title)
                .font(SableTypography.body)

            Spacer(minLength: 0)

            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 52)
    }
}
