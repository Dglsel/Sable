import Foundation

enum ReplyLanguage: String, CaseIterable, Codable, Identifiable {
    case automatic
    case chinese
    case english

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .automatic:
            "Auto"
        case .chinese:
            "Chinese"
        case .english:
            "English"
        }
    }

    var localizationKey: String {
        switch self {
        case .automatic:
            "reply.language.automatic"
        case .chinese:
            "reply.language.chinese"
        case .english:
            "reply.language.english"
        }
    }

    var mockContextLabel: String {
        switch self {
        case .automatic:
            "Auto"
        case .chinese:
            "Chinese"
        case .english:
            "English"
        }
    }
}
