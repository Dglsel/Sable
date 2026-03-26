import Foundation

@MainActor
final class OpenAIProvider: ChatProvider {
    nonisolated static let defaultID = ProviderKind.openAI.rawValue
    nonisolated static let defaultBaseURL = "https://api.openai.com/v1"
    nonisolated static let defaultModel = "gpt-4.1"

    struct Configuration: Sendable {
        let isEnabled: Bool
        let apiKey: String
        let baseURL: String
        let model: String

        init(
            isEnabled: Bool,
            apiKey: String,
            baseURL: String,
            model: String
        ) {
            self.isEnabled = isEnabled
            self.apiKey = apiKey
            self.baseURL = baseURL
            self.model = model
        }

        init(snapshot: ProviderRuntimeConfiguration) {
            self.isEnabled = snapshot.isEnabled
            self.apiKey = snapshot.apiKey
            self.baseURL = snapshot.baseURL
            self.model = snapshot.model
        }

        static let disabled = Configuration(
            isEnabled: false,
            apiKey: "",
            baseURL: OpenAIProvider.defaultBaseURL,
            model: OpenAIProvider.defaultModel
        )
    }

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
                "OpenAI provider is disabled."
            case .missingAPIKey:
                "OpenAI API key is missing."
            case .missingModel:
                "OpenAI model is not configured."
            case .invalidBaseURL:
                "OpenAI Base URL is invalid."
            case .invalidResponse:
                "OpenAI returned an invalid response."
            case .api(let message):
                message
            case .requestFailed:
                "OpenAI request failed."
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
        id: String = OpenAIProvider.defaultID,
        displayName: String = ProviderKind.openAI.displayName,
        configurationResolver: @escaping ConfigurationResolver = { .disabled },
        dataLoader: @escaping DataLoader = OpenAIProvider.liveDataLoader
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
            try Task.checkCancellation()

            do {
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

        let baseURLString = configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: baseURLString), !baseURLString.isEmpty else {
            throw ProviderError.invalidBaseURL
        }

        let endpoint = baseURL
            .appendingPathComponent("chat")
            .appendingPathComponent("completions")
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: requestMessages(from: context, latestMessage: latestMessage)
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }

    private nonisolated static func requestMessages(
        from context: Conversation,
        latestMessage: String
    ) -> [ChatCompletionRequest.Message] {
        let sortedMessages = context.messages.sorted { $0.createdAt < $1.createdAt }
        var requestMessages: [ChatCompletionRequest.Message] = sortedMessages.compactMap { message in
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else {
                return nil
            }

            switch message.role {
            case .assistant, .user, .system:
                return ChatCompletionRequest.Message(role: message.role.rawValue, content: content)
            }
        }

        let trimmedLatestMessage = latestMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        if requestMessages.isEmpty {
            if !trimmedLatestMessage.isEmpty {
                requestMessages.append(
                    ChatCompletionRequest.Message(role: MessageRole.user.rawValue, content: trimmedLatestMessage)
                )
            }
            return requestMessages
        }

        if requestMessages.last?.role != MessageRole.user.rawValue
            || requestMessages.last?.content != trimmedLatestMessage {
            if !trimmedLatestMessage.isEmpty {
                requestMessages.append(
                    ChatCompletionRequest.Message(role: MessageRole.user.rawValue, content: trimmedLatestMessage)
                )
            }
        }

        return requestMessages
    }

    private nonisolated static func parseResponse(
        data: Data,
        response: URLResponse
    ) throws -> String {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data),
               let message = errorResponse.error.message?.trimmingCharacters(in: .whitespacesAndNewlines),
               !message.isEmpty {
                throw ProviderError.api(message)
            }

            throw ProviderError.requestFailed
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw ProviderError.invalidResponse
        }

        return content
    }
}

private struct ChatCompletionRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String?
            let content: String?
        }

        let index: Int?
        let message: Message
    }

    let id: String?
    let choices: [Choice]
}

private struct OpenAIErrorResponse: Decodable {
    struct ErrorPayload: Decodable {
        let message: String?
    }

    let error: ErrorPayload
}
