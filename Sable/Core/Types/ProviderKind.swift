import Foundation

enum ProviderKind: String, CaseIterable, Codable, Identifiable {
    case openAI
    case anthropic
    case gemini
    case qwen
    case kimi
    case ollama

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            "OpenAI"
        case .anthropic:
            "Anthropic"
        case .gemini:
            "Gemini"
        case .qwen:
            "Qwen"
        case .kimi:
            "Kimi"
        case .ollama:
            "Ollama"
        }
    }

    var supportsRemoteModelDiscovery: Bool {
        true
    }

    var requiresAPIKey: Bool {
        self != .ollama
    }
}
