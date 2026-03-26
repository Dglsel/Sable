import Foundation

enum ConnectionStatus: String, Codable {
    case online
    case offline
    case setupNeeded
    case notInstalled
    case error

    var localizationKey: String {
        switch self {
        case .online:
            "connection.status.online"
        case .offline:
            "connection.status.offline"
        case .setupNeeded:
            "connection.status.setupNeeded"
        case .notInstalled:
            "connection.status.notInstalled"
        case .error:
            "connection.status.error"
        }
    }

    var defaultTitle: String {
        switch self {
        case .online:
            "Online"
        case .offline:
            "Offline"
        case .setupNeeded:
            "Setup Needed"
        case .notInstalled:
            "Not Installed"
        case .error:
            "Error"
        }
    }

    var isOnline: Bool { self == .online }

    /// Maps OpenClawStatus → ConnectionStatus for use in AppState / MenuBar.
    static func from(_ openClawStatus: OpenClawStatus) -> ConnectionStatus {
        switch openClawStatus {
        case .running:
            return .online
        case .installedStopped:
            return .offline
        case .needsOnboarding:
            return .setupNeeded
        case .notInstalled:
            return .notInstalled
        case .error:
            return .error
        }
    }
}
