import Foundation

enum InterfaceLanguage: String, CaseIterable, Codable, Identifiable {
    case followSystem
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .followSystem:
            "Follow System"
        case .simplifiedChinese:
            "简体中文"
        case .english:
            "English"
        }
    }

    var localizationKey: String {
        switch self {
        case .followSystem:
            "settings.general.language.followSystem"
        case .simplifiedChinese:
            "settings.general.language.simplifiedChinese"
        case .english:
            "settings.general.language.english"
        }
    }

    var locale: Locale {
        switch self {
        case .followSystem:
            .autoupdatingCurrent
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans")
        case .english:
            Locale(identifier: "en")
        }
    }
}
