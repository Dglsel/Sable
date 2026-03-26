import Foundation
import SwiftUI

enum AppearanceMode: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var localizationKey: String {
        switch self {
        case .system:
            "settings.general.appearance.system"
        case .light:
            "settings.general.appearance.light"
        case .dark:
            "settings.general.appearance.dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
