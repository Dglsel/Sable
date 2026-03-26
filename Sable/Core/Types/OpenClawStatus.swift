import Foundation

enum OpenClawStatus: Equatable {
    case notInstalled
    case needsOnboarding(version: String?)
    case installedStopped(version: String?)
    case running(version: String?)
    case error(message: String)

    var isInstalled: Bool {
        switch self {
        case .notInstalled:
            false
        case .needsOnboarding, .installedStopped, .running, .error:
            true
        }
    }

    var isRunning: Bool {
        if case .running = self {
            return true
        }
        return false
    }

    var isOnboarded: Bool {
        switch self {
        case .installedStopped, .running:
            true
        default:
            false
        }
    }

    var version: String? {
        switch self {
        case .notInstalled, .error:
            nil
        case .needsOnboarding(let v), .installedStopped(let v), .running(let v):
            v
        }
    }
}

enum SidebarPage: String, CaseIterable, Identifiable {
    case dashboard
    case agents
    case skills
    case chat

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chat: "Chat"
        case .dashboard: "Dashboard"
        case .agents: "Agents"
        case .skills: "Skills"
        }
    }

    var icon: String {
        switch self {
        case .chat: "bubble.left.and.text.bubble.right"
        case .dashboard: "square.grid.2x2"
        case .agents: "person.2.badge.gearshape"
        case .skills: "puzzlepiece.extension"
        }
    }
}
