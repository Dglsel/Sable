import AppKit
import SwiftUI

// MARK: - SableToolbarController

/// Installs a custom titlebar accessory that hosts all toolbar controls.
/// This completely bypasses NSToolbar item placement — we own the entire layout.
@MainActor
final class SableToolbarController: NSObject {

    private weak var window: NSWindow?
    private let appState: AppState
    private let onToggleSidebar: () -> Void
    private let onNewChat: () -> Void
    private let onOpenSettings: () -> Void

    private var accessoryVC: NSTitlebarAccessoryViewController?
    private var hostingView: NSHostingView<TitlebarView>?

    // MARK: - Init

    private init(
        window: NSWindow,
        appState: AppState,
        onToggleSidebar: @escaping () -> Void,
        onNewChat: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.window = window
        self.appState = appState
        self.onToggleSidebar = onToggleSidebar
        self.onNewChat = onNewChat
        self.onOpenSettings = onOpenSettings
        super.init()
    }

    // MARK: - Install

    @discardableResult
    static func install(
        on window: NSWindow,
        appState: AppState,
        onToggleSidebar: @escaping () -> Void,
        onNewChat: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) -> SableToolbarController {
        let controller = SableToolbarController(
            window: window,
            appState: appState,
            onToggleSidebar: onToggleSidebar,
            onNewChat: onNewChat,
            onOpenSettings: onOpenSettings
        )
        controller.setup(window: window)
        return controller
    }

    private func setup(window: NSWindow) {
        // Hide the default toolbar entirely — we draw our own
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        // Remove any existing toolbar set by SwiftUI
        window.toolbar = nil

        let titlebarView = TitlebarView(
            appState: appState,
            onToggleSidebar: onToggleSidebar,
            onNewChat: onNewChat,
            onOpenSettings: onOpenSettings
        )

        let hosting = NSHostingView(rootView: titlebarView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        self.hostingView = hosting

        let vc = NSTitlebarAccessoryViewController()
        vc.view = hosting
        // .top puts us in the same row as traffic lights
        vc.layoutAttribute = .top
        // full-width
        vc.fullScreenMinHeight = 0

        window.addTitlebarAccessoryViewController(vc)
        self.accessoryVC = vc

        // Constrain height to match standard titlebar
        hosting.heightAnchor.constraint(equalToConstant: 52).isActive = true
    }

    // MARK: - Updates

    func updateModelLabel(_ label: String) {
        hostingView?.rootView = TitlebarView(
            appState: appState,
            onToggleSidebar: onToggleSidebar,
            onNewChat: onNewChat,
            onOpenSettings: onOpenSettings
        )
    }

}

// MARK: - TitlebarView

/// The entire custom titlebar rendered in SwiftUI.
/// Traffic lights are drawn by the system to the left of this view automatically.
struct TitlebarView: View {
    let appState: AppState
    let onToggleSidebar: () -> Void
    let onNewChat: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Leading controls — left-anchored, never centered
            HStack(spacing: 2) {
                TitlebarButton(symbol: "sidebar.leading", tip: "Toggle Sidebar") {
                    onToggleSidebar()
                }

                TitlebarButton(symbol: "square.and.pencil", tip: "New Chat") {
                    onNewChat()
                }

                if !appState.toolbarModelLabel.isEmpty {
                    HStack(spacing: 3) {
                        Text(appState.toolbarModelLabel)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .fixedSize()
                    .padding(.leading, 6)
                }
            }
            .padding(.leading, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing controls
            TitlebarButton(symbol: "gearshape", tip: "Settings") {
                onOpenSettings()
            }
            .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - TitlebarButton

private struct TitlebarButton: View {
    let symbol: String
    let tip: String
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(hovered ? Color.primary : Color.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: SableRadius.sm, style: .continuous)
                        .fill(hovered ? SableTheme.bgHover : .clear)
                )
        }
        .buttonStyle(.plain)
        .help(tip)
        .onHover { hovered = $0 }
    }
}
