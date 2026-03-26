import Foundation

@MainActor
final class AnthropicProvider: ChatProvider {
    nonisolated static let defaultID = ProviderKind.anthropic.rawValue
    nonisolated static let defaultBaseURL = "https://api.anthropic.com"
    nonisolated static let defaultModel = "claude-sonnet-4-0"

    typealias Configuration = ProviderRuntimeConfiguration

    enum ProviderError: LocalizedError {
        case providerDisabled
        case missingAPIKey
        case missingModel
        case invalidBaseURL
        case invalidResponse
        case api(String)
        case requestFailed

        var errorDescription: String? {
            switch self {
            case .providerDisabled:
                "Anthropic provider is disabled."
            case .missingAPIKey:
                "Anthropic API key is missing."
            case .missingModel:
                "Anthropic model is not configured."
            case .invalidBaseURL:
                "Anthropic Base URL is invalid."
            case .invalidResponse:
                "Anthropic returned an invalid response."
            case .api(let message):
                message
            case .requestFailed:
                "Anthropic request failed."
            }
        }
    }

    typealias ConfigurationResolver = @MainActor @Sendable () -> Configuration
    typealias DataLoader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    let id: String
    let displayName: String

    private let configurationResolver: ConfigurationResolver
    private let dataLoader: DataLoader
    private var currentTask: Task<String, Error>?
    private var currentRequestID: UUID?

    init(
        id: String = AnthropicProvider.defaultID,
        displayName: String = ProviderKind.anthropic.displayName,
        configurationResolver: @escaping ConfigurationResolver = {
            ProviderRuntimeConfiguration.disabled(
                baseURL: AnthropicProvider.defaultBaseURL,
                model: AnthropicProvider.defaultModel
            )
        },
        dataLoader: @escaping DataLoader = AnthropicProvider.liveDataLoader
    ) {
        self.id = id
        self.displayName = displayName
        self.configurationResolver = configurationResolver
        self.dataLoader = dataLoader
    }

    func sendMessage(_ message: String, context: Conversation) async throws -> String {
        currentTask?.cancel()

        let configuration = configurationResolver()
        let request = try Self.buildRequest(
            latestMessage: message,
            context: context,
            configuration: configuration
        )
        let requestID = UUID()
        let dataLoader = self.dataLoader

        let task = Task<String, Error> {
            do {
                try Task.checkCancellation()
                let (data, response) = try await dataLoader(request)
                try Task.checkCancellation()
                return try Self.parseResponse(data: data, response: response)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch let error as ProviderError {
                throw error
            } catch {
                throw ProviderError.requestFailed
            }
        }

        currentTask = task
        currentRequestID = requestID

        defer {
            if currentRequestID == requestID {
                currentTask = nil
                currentRequestID = nil
            }
        }

        return try await task.value
    }

    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    private nonisolated static func liveDataLoader(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }

    private nonisolated static func buildRequest(
        latestMessage: String,
        context: Conversation,
        configuration: Configuration
    ) throws -> URLRequest {
        guard configuration.isEnabled else {
            throw ProviderError.providerDisabled
        }

        let apiKey = configuration.apiKey.removingWhitespaceAndNewlines
        guard !apiKey.isEmpty else {
            throw ProviderError.missingAPIKey
        }

        let model = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            throw ProviderError.missingModel
        }

        guard let baseURL = ProviderRequestSupport.validatedBaseURL(configuration.baseURL) else {
            throw ProviderError.invalidBaseURL
        }

        let requestMessages = ProviderRequestSupport.requestMessages(from: context, latestMessage: latestMessage)
        let endpoint = baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("messages")
        let requestBody = MessagesRequest(
            model: model,
            system: ProviderRequestSupport.systemPrompt(from: requestMessages),
            messages: requestMessages
                .filter { $0.role != .system }
                .map {
                    MessagesRequest.Message(
                        role: $0.role.rawValue,
                        content: [MessagesRequest.TextContent(text: $0.content)]
                    )
                }
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }

    private nonisolated static func parseResponse(
        data: Data,
        response: URLResponse
    ) throws -> String {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorResponse = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data),
               let message = errorResponse.error.message?.trimmingCharacters(in: .whitespacesAndNewlines),
               !message.isEmpty {
                throw ProviderError.api(message)
            }

            throw ProviderError.requestFailed
        }

        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        guard let content = decoded.content
            .compactMap(\.text)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            throw ProviderError.invalidResponse
        }

        return content
    }
}

private struct MessagesRequest: Codable {
    struct TextContent: Codable {
        let type: String
        let text: String

        init(text: String) {
            self.type = "text"
            self.text = text
        }
    }

    struct Message: Codable {
        let role: String
        let content: [TextContent]
    }

    let model: String
    let max_tokens: Int
    let system: String?
    let messages: [Message]

    init(model: String, system: String?, messages: [Message], maxTokens: Int = 4096) {
        self.model = model
        self.system = system
        self.messages = messages
        self.max_tokens = maxTokens
    }
}

private struct MessagesResponse: Codable {
    struct ContentBlock: Codable {
        let type: String?
        let text: String?
    }

    let id: String?
    let content: [ContentBlock]
}

private struct AnthropicErrorResponse: Decodable {
    struct ErrorPayload: Decodable {
        let message: String?
    }

    let error: ErrorPayload
}
