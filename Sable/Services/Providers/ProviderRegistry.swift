import Foundation

struct ProviderDefinition: Identifiable {
    let kind: ProviderKind
    let defaultModel: String
    let defaultBaseURL: String

    var id: ProviderKind { kind }
}

@MainActor
final class ProviderRegistry {
    nonisolated static let all: [ProviderDefinition] = [
        ProviderDefinition(kind: .openAI, defaultModel: "gpt-4.1", defaultBaseURL: "https://api.openai.com/v1"),
        ProviderDefinition(kind: .anthropic, defaultModel: "claude-sonnet-4-0", defaultBaseURL: "https://api.anthropic.com"),
        ProviderDefinition(kind: .gemini, defaultModel: "gemini-2.5-flash", defaultBaseURL: "https://generativelanguage.googleapis.com"),
        ProviderDefinition(kind: .qwen, defaultModel: "qwen-plus", defaultBaseURL: "https://dashscope.aliyuncs.com/compatible-mode"),
        ProviderDefinition(kind: .kimi, defaultModel: "moonshot-v1-8k", defaultBaseURL: "https://api.moonshot.cn"),
        ProviderDefinition(kind: .ollama, defaultModel: "llama3.2", defaultBaseURL: "http://localhost:11434")
    ]

    private var providersByID: [String: any ChatProvider] = [:]
    private var providerOrder: [String] = []

    init(providers: [any ChatProvider] = []) {
        for provider in providers {
            register(provider)
        }
    }

    var registeredProviders: [any ChatProvider] {
        providerOrder.compactMap { providersByID[$0] }
    }

    var defaultProvider: (any ChatProvider)? {
        providerOrder.first.flatMap { providersByID[$0] }
    }

    func register(_ provider: any ChatProvider) {
        if providersByID[provider.id] == nil {
            providerOrder.append(provider.id)
        }
        providersByID[provider.id] = provider
    }

    func provider(for id: String) -> (any ChatProvider)? {
        providersByID[id]
    }

    private var preferredDefaultProviderID: String? {
        if providersByID[MockProvider.defaultID] != nil {
            return MockProvider.defaultID
        }

        return providerOrder.first
    }
}
