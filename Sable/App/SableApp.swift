import SwiftUI

@main
struct SableApp: App {
    @State private var container = AppContainer()

    /// Extracted so SwiftUI can directly observe the nested @Observable property
    /// and re-evaluate .preferredColorScheme when the user changes appearance.
    private var colorScheme: ColorScheme? {
        container.appState.appearanceMode.colorScheme
    }

    var body: some Scene {
        WindowGroup(id: WindowNavigator.mainWindowID) {
            AppScene()
                .environment(container)
                .environment(container.appState)
                .environment(container.openClawService)
                .modelContainer(container.persistenceController.modelContainer)
                .environment(\.locale, container.appState.interfaceLocale)
                .preferredColorScheme(colorScheme)
                .tint(SableTheme.interactive)
                .onAppear { container.openClawService.startPolling() }
                .background(
                    WindowToolbarInstaller(
                        appState: container.appState,
                        openClawService: container.openClawService
                    )
                )
        }
        .defaultSize(width: 1220, height: 780)

        Window(L10n.string("settings.title", default: "Settings"), id: WindowNavigator.settingsWindowID) {
            SettingsView()
                .environment(container)
                .environment(container.appState)
                .modelContainer(container.persistenceController.modelContainer)
                .environment(\.locale, container.appState.interfaceLocale)
                .preferredColorScheme(colorScheme)
                .tint(SableTheme.interactive)
                .id(container.appState.interfaceLanguage)
        }
        .defaultSize(width: 560, height: 640)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarPanelView()
                .environment(container)
                .environment(container.appState)
                .modelContainer(container.persistenceController.modelContainer)
                .environment(\.locale, container.appState.interfaceLocale)
                .preferredColorScheme(colorScheme)
                .tint(SableTheme.interactive)
        } label: {
            Label("Sable", systemImage: "bubble.left.and.text.bubble.right")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let clawHubNewChat      = Notification.Name("com.sable.newChat")
    static let clawHubOpenSettings = Notification.Name("com.sable.openSettings")
    static let clawHubToggleSidebar = Notification.Name("com.sable.toggleSidebar")
}

// MARK: - WindowToolbarInstaller

private struct WindowToolbarInstaller: NSViewRepresentable {
    let appState: AppState
    let openClawService: OpenClawService

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState, openClawService: openClawService)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.frame = .zero
        context.coordinator.scheduleInstall(view: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.sync()
    }

    @MainActor
    final class Coordinator: NSObject {
        let appState: AppState
        let openClawService: OpenClawService
        weak var view: NSView?
        var toolbarController: SableToolbarController?

        init(appState: AppState, openClawService: OpenClawService) {
            self.appState = appState
            self.openClawService = openClawService
        }

        func scheduleInstall(view: NSView) {
            self.view = view
            tryInstall()
        }

        private func tryInstall() {
            guard let window = view?.window else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.tryInstall()
                }
                return
            }
            guard toolbarController == nil else { return }

            toolbarController = SableToolbarController.install(
                on: window,
                appState: appState,
                onToggleSidebar: {
                    NotificationCenter.default.post(name: .clawHubToggleSidebar, object: nil)
                },
                onNewChat: {
                    NotificationCenter.default.post(name: .clawHubNewChat, object: nil)
                },
                onOpenSettings: {
                    NotificationCenter.default.post(name: .clawHubOpenSettings, object: nil)
                }
            )
        }

        func sync() {
            toolbarController?.updateModelLabel(appState.toolbarModelLabel)
            applyAppearance()
        }

        private func applyAppearance() {
            guard let window = view?.window else { return }
            switch appState.appearanceMode {
            case .system:
                window.appearance = nil
            case .light:
                window.appearance = NSAppearance(named: .aqua)
            case .dark:
                window.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
}
