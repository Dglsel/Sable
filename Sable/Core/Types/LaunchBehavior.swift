import Foundation

enum LaunchBehavior: String, CaseIterable, Codable, Identifiable {
    case reopenLastConversation
    case startEmpty

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .reopenLastConversation:
            "Reopen Last Conversation"
        case .startEmpty:
            "Start Empty"
        }
    }

    var localizationKey: String {
        switch self {
        case .reopenLastConversation:
            "settings.general.launch.reopenLastConversation"
        case .startEmpty:
            "settings.general.launch.startEmpty"
        }
    }
}
