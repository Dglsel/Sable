import Foundation

struct ProviderModelDiscoveryService {
    enum DiscoveryError: LocalizedError, Equatable {
        case missingAPIKey
        case invalidBaseURL
        case invalidResponse
        case requestFailed
        case api(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                "API Key is missing."
            case .invalidBaseURL:
                "Base URL is invalid."
            case .invalidResponse:
                "Provider returned an invalid model list."
            case .requestFailed:
                "Model discovery request failed."
            case .api(let message):
                message
            }
        }
    }

    typealias DataLoader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let dataLoader: DataLoader

    init(dataLoader: @escaping DataLoader = Self.liveDataLoader) {
        self.dataLoader = dataLoader
    }

    func fetchModels(
        for provider: ProviderKind,
        apiKey: String,
        baseURL: String
    ) async throws -> [String] {
        if !provider.supportsRemoteModelDiscovery {
            return ProviderModelCatalog.suggestedModels(for: provider)
        }

        let normalizedAPIKey = apiKey.removingWhitespaceAndNewlines
        let requiresAPIKey = provider != .ollama
        guard !requiresAPIKey || !normalizedAPIKey.isEmpty else {
            throw DiscoveryError.missingAPIKey
        }

        guard let validatedBaseURL = ProviderRequestSupport.validatedBaseURL(baseURL) else {
            throw DiscoveryError.invalidBaseURL
        }

        let request = Self.buildRequest(
            provider: provider,
            apiKey: normalizedAPIKey,
            baseURL: validatedBaseURL
        )
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await dataLoader(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw DiscoveryError.requestFailed
        }

        return try Self.parseModels(for: provider, data: data, response: response)
    }

    private nonisolated static func liveDataLoader(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }

    private nonisolated static func buildRequest(
        provider: ProviderKind,
        apiKey: String,
        baseURL: URL
    ) -> URLRequest {
        var request: URLRequest

        switch provider {
        case .openAI:
            request = URLRequest(url: modelsEndpoint(baseURL: baseURL, versionPath: "v1"))
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .anthropic:
            request = URLRequest(url: modelsEndpoint(baseURL: baseURL, versionPath: "v1"))
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .gemini:
            request = URLRequest(url: modelsEndpoint(baseURL: baseURL, versionPath: "v1beta"))
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        case .qwen:
            request = URLRequest(url: modelsEndpoint(baseURL: baseURL, versionPath: "v1"))
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .kimi:
            request = URLRequest(url: modelsEndpoint(baseURL: baseURL, versionPath: "v1"))
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .ollama:
            request = URLRequest(url: baseURL.appendingPathComponent("api").appendingPathComponent("tags"))
        }

        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private nonisolated static func modelsEndpoint(baseURL: URL, versionPath: String) -> URL {
        let normalizedPath = baseURL.path.lowercased()
        if normalizedPath.split(separator: "/").contains(Substring(versionPath.lowercased())) {
            return baseURL.appendingPathComponent("models")
        }

        return baseURL
            .appendingPathComponent(versionPath)
            .appendingPathComponent("models")
    }

    private nonisolated static func parseModels(
        for provider: ProviderKind,
        data: Data,
        response: URLResponse
    ) throws -> [String] {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscoveryError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorMessage = parseErrorMessage(from: data) {
                throw DiscoveryError.api(errorMessage)
            }

            throw DiscoveryError.requestFailed
        }

        let models: [String]
        switch provider {
        case .openAI, .anthropic, .qwen, .kimi:
            models = try parseOpenAIStyleModels(from: data)
        case .gemini:
            models = try parseGeminiModels(from: data)
        case .ollama:
            models = try parseOllamaModels(from: data)
        }

        let normalized = normalizedModelIDs(models)
        guard !normalized.isEmpty else {
            throw DiscoveryError.invalidResponse
        }

        return normalized
    }

    private nonisolated static func parseOpenAIStyleModels(from data: Data) throws -> [String] {
        let payload = try JSONDecoder().decode(ModelsListResponse.self, from: data)
        return payload.data.map(\.id)
    }

    private nonisolated static func parseGeminiModels(from data: Data) throws -> [String] {
        let payload = try JSONDecoder().decode(GeminiModelsListResponse.self, from: data)

        return payload.models.compactMap { model in
            let methods = Set(model.supportedGenerationMethods ?? [])
            guard methods.contains("generateContent") else {
                return nil
            }

            return model.name.replacingOccurrences(of: "models/", with: "")
        }
    }

    private nonisolated static func parseOllamaModels(from data: Data) throws -> [String] {
        let payload = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
        return payload.models.map(\.name)
    }

    private nonisolated static func normalizedModelIDs(_ models: [String]) -> [String] {
        let normalized = models
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(Set(normalized)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private nonisolated static func parseErrorMessage(from data: Data) -> String? {
        if let payload = try? JSONDecoder().decode(GenericErrorResponse.self, from: data),
           let message = payload.error.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return message
        }

        return nil
    }
}

private struct ModelsListResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}

private struct GeminiModelsListResponse: Decodable {
    struct Model: Decodable {
        let name: String
        let supportedGenerationMethods: [String]?
    }

    let models: [Model]
}

private struct OllamaModelsResponse: Decodable {
    struct Model: Decodable {
        let name: String
    }

    let models: [Model]
}

private struct GenericErrorResponse: Decodable {
    struct ErrorPayload: Decodable {
        let message: String?
    }

    let error: ErrorPayload
}
