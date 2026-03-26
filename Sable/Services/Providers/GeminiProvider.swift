import Foundation

@MainActor
final class GeminiProvider: ChatProvider {
    nonisolated static let defaultID = ProviderKind.gemini.rawValue
    nonisolated static let defaultBaseURL = "https://generativelanguage.googleapis.com"
    nonisolated static let defaultModel = "gemini-2.5-flash"

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
                "Gemini provider is disabled."
            case .missingAPIKey:
                "Gemini API key is missing."
            case .missingModel:
                "Gemini model is not configured."
            case .invalidBaseURL:
                "Gemini Base URL is invalid."
            case .invalidResponse:
                "Gemini returned an invalid response."
            case .api(let message):
                message
            case .requestFailed:
                "Gemini request failed."
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
        id: String = GeminiProvider.defaultID,
        displayName: String = ProviderKind.gemini.displayName,
        configurationResolver: @escaping ConfigurationResolver = {
            ProviderRuntimeConfiguration.disabled(
                baseURL: GeminiProvider.defaultBaseURL,
                model: GeminiProvider.defaultModel
            )
        },
        dataLoader: @escaping DataLoader = GeminiProvider.simulatedDataLoader
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

    private nonisolated static func simulatedDataLoader(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await Task.sleep(for: .milliseconds(220))
        try Task.checkCancellation()
        guard let url = request.url else {
            throw ProviderError.invalidResponse
        }

        let requestBody = try JSONDecoder().decode(GenerateContentRequest.self, from: request.httpBody ?? Data())
        let latestMessage = requestBody.contents.last?.parts.last?.text ?? ""
        let reply = ProviderRequestSupport.simulatedReply(
            providerName: ProviderKind.gemini.displayName,
            latestMessage: latestMessage
        )
        let responseBody = GenerateContentResponse(
            candidates: [
                GenerateContentResponse.Candidate(
                    content: GenerateContentResponse.Content(
                        parts: [GenerateContentResponse.Part(text: reply)]
                    )
                )
            ]
        )
        let data = try JSONEncoder().encode(responseBody)
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ) else {
            throw ProviderError.invalidResponse
        }
        return (data, response)
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
            .appendingPathComponent("v1beta")
            .appendingPathComponent("models")
            .appendingPathComponent("\(model):generateContent")
        let requestBody = GenerateContentRequest(
            contents: requestMessages
                .filter { $0.role != .system }
                .map {
                    GenerateContentRequest.Content(
                        role: $0.role == .assistant ? "model" : "user",
                        parts: [GenerateContentRequest.Part(text: $0.content)]
                    )
                },
            systemInstruction: ProviderRequestSupport.systemPrompt(from: requestMessages)
                .map { GenerateContentRequest.SystemInstruction(parts: [GenerateContentRequest.Part(text: $0)]) }
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
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
            if let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data),
               let message = errorResponse.error.message?.trimmingCharacters(in: .whitespacesAndNewlines),
               !message.isEmpty {
                throw ProviderError.api(message)
            }

            throw ProviderError.requestFailed
        }

        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        guard let content = decoded.candidates
            .flatMap(\.content.parts)
            .compactMap(\.text)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            throw ProviderError.invalidResponse
        }

        return content
    }
}

private struct GenerateContentRequest: Codable {
    struct Part: Codable {
        let text: String
    }

    struct Content: Codable {
        let role: String
        let parts: [Part]
    }

    struct SystemInstruction: Codable {
        let parts: [Part]
    }

    let contents: [Content]
    let systemInstruction: SystemInstruction?
}

private struct GenerateContentResponse: Codable {
    struct Candidate: Codable {
        let content: Content
    }

    struct Content: Codable {
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String?
    }

    let candidates: [Candidate]
}

private struct GeminiErrorResponse: Decodable {
    struct ErrorPayload: Decodable {
        let message: String?
    }

    let error: ErrorPayload
}
