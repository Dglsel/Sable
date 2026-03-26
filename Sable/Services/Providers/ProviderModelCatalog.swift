import Foundation

enum ProviderModelCatalog {
    static func suggestedModels(for provider: ProviderKind) -> [String] {
        switch provider {
        case .openAI:
            ["gpt-4.1", "gpt-4.0", "gpt-3.5-turbo"]
        case .anthropic:
            ["claude-2", "claude-3", "claude-sonnet-4-0"]
        case .gemini:
            ["gemini-1", "gemini-2", "gemini-3"]
        case .qwen:
            ["qwen-turbo", "qwen-plus", "qwen-max"]
        case .kimi:
            ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"]
        case .ollama:
            ["llama3.2", "mistral", "qwen2.5"]
        }
    }

    static func modelOptions(
        for provider: ProviderKind,
        currentSelection: String,
        preferredModels: [String] = []
    ) -> [String] {
        let trimmedSelection = currentSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        var options = normalizedModelList(preferredModels)

        if options.isEmpty {
            options = suggestedModels(for: provider)
        }

        if !trimmedSelection.isEmpty, !options.contains(trimmedSelection) {
            options.insert(trimmedSelection, at: 0)
        }

        return options
    }

    private static func normalizedModelList(_ models: [String]) -> [String] {
        let normalized = models
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(normalized.count)

        for model in normalized where seen.insert(model).inserted {
            result.append(model)
        }

        return result
    }
}
