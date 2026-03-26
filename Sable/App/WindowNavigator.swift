import AppKit

enum WindowNavigator {
    static let mainWindowID = "main-window"
    static let settingsWindowID = "settings-window"

    static func activateApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    /// Brings the existing main window to front without creating a new one.
    /// SwiftUI `WindowGroup(id:)` appends suffixes to NSWindow.identifier,
    /// so we match with `contains` rather than exact equality.
    static func activateMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        // 1. Try to find by identifier containing our main window ID
        let mainWindow = NSApplication.shared.windows.first { window in
            guard let id = window.identifier?.rawValue else { return false }
            return id.contains(mainWindowID) && !id.contains(settingsWindowID)
        }

        // 2. Fallback: first visible non-settings, non-panel window
        let fallback = NSApplication.shared.windows.first { window in
            let id = window.identifier?.rawValue ?? ""
            guard !id.contains(settingsWindowID) else { return false }
            guard !window.title.contains("Settings") else { return false }
            // Skip panels, sheets, and other utility windows
            return window.level == .normal && (window.isVisible || window.isMiniaturized)
        }

        if let target = mainWindow ?? fallback {
            if target.isMiniaturized { target.deminiaturize(nil) }
            target.makeKeyAndOrderFront(nil)
        }
    }
}
