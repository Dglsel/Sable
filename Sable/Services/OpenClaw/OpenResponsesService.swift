import Foundation
import os

/// HTTP+SSE client for OpenClaw's `/v1/responses` API.
/// Replaces ACP WebSocket as the primary chat channel.
@MainActor
final class OpenResponsesService {

    private static let logger = Logger(subsystem: "ai.sable", category: "OpenResponsesService")

    // MARK: - Types

    enum ServiceError: Error {
        case connectionFailed
        case requestFailed(statusCode: Int, body: String)
        case decodingFailed
    }

    struct Attachment: Sendable {
        enum Kind: Sendable { case image, file }
        let kind: Kind
        let mimeType: String
        let base64Data: String
        let fileName: String
    }

    enum StreamEvent: Sendable {
        case delta(text: String)
        case reasoningDelta(text: String)
        case toolCall(name: String)
        case completed(text: String, usage: Usage?)
        case error(String)
        /// Emitted when the service auto-retries a failed request.
        case retrying(attempt: Int, maxAttempts: Int)

        struct Usage: Sendable {
            let inputTokens: Int?
            let outputTokens: Int?
        }
    }

    // MARK: - Retry Configuration

    private static let maxRetryAttempts = 3
    private static let retryBaseDelay: TimeInterval = 2.0  // 2s → 4s → 8s

    // MARK: - Session

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = [:]
        // 180s between data packets — tool chains (search → read → execute → write)
        // can stall the SSE stream for extended periods while the agent works
        config.timeoutIntervalForRequest = 180
        // 10min total — complex multi-step agent tasks need headroom
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    /// Cancel any in-flight streaming request — closes the HTTP connection
    /// so the server stops generating tokens.
    func cancelStreaming() {
        session.getAllTasks { tasks in
            for task in tasks { task.cancel() }
        }
    }

    // MARK: - Public API

    func sendMessage(
        _ prompt: String,
        model: String,
        conversationId: String,
        attachments: [Attachment] = [],
        stream: Bool = true
    ) async throws -> AsyncStream<StreamEvent> {
        let config = GatewayConfig.readFromDisk()
        guard let baseURL = config.baseURL else {
            throw ServiceError.connectionFailed
        }

        let url = baseURL.appendingPathComponent("v1/responses")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        if let token = config.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Build input — must be wrapped in a message item for the gateway to parse
        let input: Any
        if attachments.isEmpty {
            // Simple text-only: string input is accepted
            input = prompt
        } else {
            // Multimodal: wrap in a user message item with content parts
            var contentParts: [[String: Any]] = [
                ["type": "input_text", "text": prompt]
            ]
            for attachment in attachments {
                switch attachment.kind {
                case .image:
                    contentParts.append([
                        "type": "input_image",
                        "source": [
                            "type": "base64",
                            "media_type": attachment.mimeType,
                            "data": attachment.base64Data
                        ] as [String: Any]
                    ])
                case .file:
                    contentParts.append([
                        "type": "input_file",
                        "source": [
                            "type": "base64",
                            "media_type": attachment.mimeType,
                            "data": attachment.base64Data,
                            "filename": attachment.fileName
                        ] as [String: Any]
                    ])
                }
            }
            input = [
                [
                    "type": "message",
                    "role": "user",
                    "content": contentParts
                ] as [String: Any]
            ] as [[String: Any]]
        }

        // Build body
        let prefix = String(conversationId.prefix(8))
        let body: [String: Any] = [
            "model": model,
            "input": input,
            "stream": stream,
            "user": "sable-\(prefix)"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        Self.logger.info("POST \(url.absoluteString) stream=\(stream) model=\(model)")

        if stream {
            return try await streamingRequestWithRetry(request)
        } else {
            return try await nonStreamingRequest(request)
        }
    }

    // MARK: - Retry Wrapper

    /// Wraps `streamingRequest` with automatic retry for transient failures.
    /// Emits `.retrying` events so the UI can show "Retrying 1/3…" status.
    private func streamingRequestWithRetry(_ request: URLRequest) async throws -> AsyncStream<StreamEvent> {
        // First attempt — no retry overhead
        do {
            return try await streamingRequest(request)
        } catch let error as ServiceError where Self.isRetryable(error) {
            Self.logger.warning("First attempt failed (retryable): \(String(describing: error))")
        } catch let error where Self.isRetryableNSError(error as NSError) {
            Self.logger.warning("First attempt failed (retryable network): \(error.localizedDescription)")
        }
        // Non-retryable errors propagate naturally from the try above

        // Subsequent attempts — wrapped in AsyncStream so we can emit .retrying events
        let maxAttempts = Self.maxRetryAttempts
        let baseDelay = Self.retryBaseDelay
        let logger = Self.logger

        return AsyncStream { [weak self] continuation in
            let task = Task { @MainActor [weak self] in
                guard let self else { continuation.finish(); return }

                for attempt in 1 ..< maxAttempts {
                    // Notify UI of retry
                    continuation.yield(.retrying(attempt: attempt, maxAttempts: maxAttempts))

                    let delay = baseDelay * pow(2.0, Double(attempt - 1))
                    logger.info("Retry \(attempt)/\(maxAttempts) after \(delay)s")
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { continuation.finish(); return }

                    do {
                        let innerStream = try await self.streamingRequest(request)
                        // Relay all events from the successful retry
                        for await event in innerStream {
                            continuation.yield(event)
                        }
                        continuation.finish()
                        return
                    } catch {
                        let isRetryable = (error is ServiceError)
                            ? Self.isRetryable(error as! ServiceError)
                            : Self.isRetryableNSError(error as NSError)

                        if !isRetryable || attempt == maxAttempts - 1 {
                            let message = Self.friendlyErrorMessage(for: error)
                            continuation.yield(.error(message))
                            continuation.finish()
                            return
                        }
                        logger.warning("Retry \(attempt) failed: \(error.localizedDescription)")
                    }
                }

                continuation.yield(.error("All retry attempts failed."))
                continuation.finish()
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Whether a ServiceError warrants a retry.
    private static func isRetryable(_ error: ServiceError) -> Bool {
        switch error {
        case .requestFailed(let code, _):
            // 408 timeout, 429 rate limit, 502/503/504 upstream, 529 overloaded
            return [408, 429, 502, 503, 504, 529].contains(code)
        case .connectionFailed, .decodingFailed:
            return false
        }
    }

    /// Whether an NSError (network-level) warrants a retry.
    private nonisolated static func isRetryableNSError(_ error: NSError) -> Bool {
        [NSURLErrorTimedOut,
         NSURLErrorNetworkConnectionLost,
         NSURLErrorCannotConnectToHost].contains(error.code)
    }

    // MARK: - Non-Streaming

    private func nonStreamingRequest(_ request: URLRequest) async throws -> AsyncStream<StreamEvent> {
        let (data, response) = try await session.data(for: request)
        let httpResponse = response as? HTTPURLResponse

        guard let statusCode = httpResponse?.statusCode, (200 ..< 300).contains(statusCode) else {
            let code = httpResponse?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            Self.logger.error("Non-streaming request failed: \(code) \(body.prefix(500))")
            throw ServiceError.requestFailed(statusCode: code, body: body)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.decodingFailed
        }

        let text = Self.extractOutputText(from: json)
        let usage = Self.extractUsage(from: json)

        return AsyncStream { continuation in
            continuation.yield(.completed(text: text, usage: usage))
            continuation.finish()
        }
    }

    // MARK: - Streaming (SSE)

    private func streamingRequest(_ request: URLRequest) async throws -> AsyncStream<StreamEvent> {
        var sseRequest = request
        sseRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await session.bytes(for: sseRequest)
        } catch {
            Self.logger.error("SSE connection failed: \(error.localizedDescription)")
            // Throw instead of returning error event — allows retry wrapper to catch & retry
            throw error
        }

        let httpResponse = response as? HTTPURLResponse
        guard let statusCode = httpResponse?.statusCode, (200 ..< 300).contains(statusCode) else {
            // Read error body from the byte stream
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte); if errorData.count > 4096 { break } }
            let body = String(data: errorData, encoding: .utf8) ?? ""
            let code = httpResponse?.statusCode ?? 0
            Self.logger.error("SSE request failed: \(code) \(body.prefix(500))")
            throw ServiceError.requestFailed(statusCode: code, body: body)
        }

        // We need to transfer the nonisolated bytes iterator into the stream's Task.
        // Wrap in a Sendable box to cross the isolation boundary.
        let sendableBytes = UncheckedSendableBox(value: bytes)
        let logger = Self.logger

        return AsyncStream { continuation in
            let task = Task.detached { [weak self] in
                var currentEvent: String?
                var dataBuffer = ""

                func flushCurrentEvent() async -> Bool {
                    guard !dataBuffer.isEmpty, let event = currentEvent else { return false }

                    let events = await self?.processSSEEvent(event: event, data: dataBuffer)
                    currentEvent = nil
                    dataBuffer = ""

                    for e in events ?? [] {
                        continuation.yield(e)
                        if case .completed = e {
                            continuation.finish()
                            return true
                        }
                        if case .error = e {
                            continuation.finish()
                            return true
                        }
                    }

                    return false
                }

                do {
                    for try await rawLine in sendableBytes.value.lines {
                        let line = rawLine.hasSuffix("\r")
                            ? String(rawLine.dropLast())
                            : rawLine

                        if line.hasPrefix("event: ") {
                            if await flushCurrentEvent() {
                                return
                            }
                            currentEvent = String(line.dropFirst(7))
                            continue
                        }

                        if line.hasPrefix("data: ") {
                            if line == "data: [DONE]" {
                                if await flushCurrentEvent() {
                                    return
                                }
                                continue
                            }

                            // Append for multi-line data payloads (SSE spec)
                            if dataBuffer.isEmpty {
                                dataBuffer = String(line.dropFirst(6))
                            } else {
                                dataBuffer += "\n" + String(line.dropFirst(6))
                            }
                        } else if line.isEmpty {
                            if await flushCurrentEvent() {
                                return
                            }
                            continue
                        }
                    }

                    if await flushCurrentEvent() { return }

                    // If the server closed without a terminal event, surface it as an error
                    // so the UI doesn't leave behind an empty streaming bubble.
                    continuation.yield(.error("Streaming ended before a final response was received."))
                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        logger.error("SSE read error: \(error.localizedDescription)")
                        let message = Self.friendlyErrorMessage(for: error)
                        continuation.yield(.error(message))
                    }
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - SSE Event Processing

    private func processSSEEvent(event: String, data: String) -> [StreamEvent] {
        switch event {
        case "response.output_text.delta":
            guard let json = Self.parseJSON(data),
                  let delta = json["delta"] as? String else { return [] }
            return [.delta(text: delta)]

        case "response.completed":
            guard let json = Self.parseJSON(data),
                  let responseObj = json["response"] as? [String: Any] else {
                return [.completed(text: "", usage: nil)]
            }
            let text = Self.extractOutputText(from: responseObj)
            let usage = Self.extractUsage(from: responseObj)
            return [.completed(text: text, usage: usage)]

        case "response.failed":
            let json = Self.parseJSON(data)
            let message = (json?["error"] as? [String: Any])?["message"] as? String
                ?? "Response failed"
            Self.logger.error("SSE response.failed: \(message)")
            return [.error(message)]

        case "response.output_item.added":
            guard let json = Self.parseJSON(data),
                  let item = json["item"] as? [String: Any],
                  let itemType = item["type"] as? String else { return [] }
            switch itemType {
            case "function_call":
                guard let name = item["name"] as? String else { return [] }
                return [.toolCall(name: name)]
            case "web_search_call":
                return [.toolCall(name: "web_search")]
            default:
                return []
            }

        case "response.reasoning_summary_text.delta":
            guard let json = Self.parseJSON(data),
                  let delta = json["delta"] as? String else { return [] }
            return [.reasoningDelta(text: delta)]

        default:
            return []
        }
    }

    // MARK: - Helpers

    private static func extractOutputText(from response: [String: Any]) -> String {
        guard let output = response["output"] as? [[String: Any]] else { return "" }
        var texts: [String] = []
        for item in output {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for part in content {
                if (part["type"] as? String) == "output_text",
                   let text = part["text"] as? String {
                    texts.append(text)
                }
            }
        }
        return texts.joined()
    }

    private static func extractUsage(from response: [String: Any]) -> StreamEvent.Usage? {
        guard let usage = response["usage"] as? [String: Any] else { return nil }
        return StreamEvent.Usage(
            inputTokens: usage["input_tokens"] as? Int,
            outputTokens: usage["output_tokens"] as? Int
        )
    }

    nonisolated private static func friendlyErrorMessage(for error: Error) -> String {
        let nsError = error as NSError

        // Timeout — most common when upstream model is unresponsive
        if nsError.code == NSURLErrorTimedOut {
            return "Model not responding — the upstream provider may be down or overloaded. Try again later or switch to a different model."
        }

        // Network unreachable / cannot connect
        if nsError.code == NSURLErrorCannotConnectToHost ||
           nsError.code == NSURLErrorNetworkConnectionLost ||
           nsError.code == NSURLErrorNotConnectedToInternet {
            return "Cannot reach the gateway. Make sure OpenClaw is running."
        }

        // Cancelled by user (stop button) — should not surface as error
        if nsError.code == NSURLErrorCancelled {
            return "Request cancelled."
        }

        return error.localizedDescription
    }

    private static func parseJSON(_ string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}

// MARK: - Sendable Wrapper

/// Wraps a non-Sendable value for crossing isolation boundaries when safety is guaranteed by usage context.
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
}
