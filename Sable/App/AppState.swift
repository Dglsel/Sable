import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var selectedConversationID: UUID?
    var isSidebarOpen: Bool = true
    var activePage: SidebarPage = .dashboard
    var interfaceLanguage: InterfaceLanguage
    var appearanceMode: AppearanceMode
    var connectionStatus: ConnectionStatus
    var toolbarModelLabel: String = ""

    init(settings: AppSettings, selectedConversationID: UUID?) {
        self.selectedConversationID = selectedConversationID
        self.interfaceLanguage = settings.interfaceLanguage
        self.appearanceMode = settings.appearanceMode
        self.connectionStatus = .notInstalled
        L10n.currentLanguage = settings.interfaceLanguage
    }

    var interfaceLocale: Locale {
        interfaceLanguage.locale
    }

    func sync(with settings: AppSettings) {
        interfaceLanguage = settings.interfaceLanguage
        appearanceMode = settings.appearanceMode
    }

    /// Immediately applies the current appearanceMode to all open NSWindows.
    /// Call this after changing appearanceMode so the UI updates without requiring
    /// a focus change (which is when SwiftUI's .preferredColorScheme normally kicks in).
    func applyAppearanceToAllWindows() {
        let nsAppearance: NSAppearance? = switch appearanceMode {
        case .system: nil
        case .light:  NSAppearance(named: .aqua)
        case .dark:   NSAppearance(named: .darkAqua)
        }
        for window in NSApp.windows {
            window.appearance = nsAppearance
        }
    }
}
