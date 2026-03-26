import Foundation
import os

/// Minimal ACP (Agent Communication Protocol) client for OpenClaw gateway.
/// Handles WebSocket connection, challenge-based handshake, and frame exchange.
/// Phase 1: text block streaming only.
@MainActor
final class ACPClient {

    private static let logger = Logger(subsystem: "ai.sable", category: "ACPClient")

    // MARK: - Types

    enum ACPError: Error {
        case connectionFailed(String)
        case handshakeFailed(String)
        case notConnected
        case requestFailed(String)
        case timeout
    }

    /// Raw ACP frame — covers req/res/event.
    struct Frame: Codable {
        let type: String
        let id: String?
        let method: String?
        let params: AnyCodable?
        let ok: Bool?
        let payload: AnyCodable?
        let error: FrameError?
        let event: String?
        let seq: Int?

        struct FrameError: Codable {
            let code: String?
            let message: String?
            let retryable: Bool?
        }
    }

    /// Streaming event emitted to consumers.
    enum StreamEvent: Sendable {
        case delta(text: String, seq: Int)
        case final_(text: String, usage: Usage?)
        case error(String)

        struct Usage: Sendable {
            let inputTokens: Int?
            let outputTokens: Int?
        }
    }

    // MARK: - State

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false
    private var pendingContinuations: [String: CheckedContinuation<Frame, Error>] = [:]
    private var eventHandler: ((Frame) -> Void)?
    private var receiveTask: Task<Void, Never>?

    // MARK: - Connect

    /// Connect to gateway, complete ACP handshake.
    func connect(url: URL, token: String?) async throws {
        Self.logger.info("Connecting to \(url.absoluteString)")

        // Bypass system proxy for localhost — VPN/proxy can intercept loopback connections
        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = [:]
        let urlSession = URLSession(configuration: config)
        let ws = urlSession.webSocketTask(with: url)
        ws.resume()

        self.session = urlSession
        self.webSocket = ws

        // Start receiving frames immediately
        startReceiveLoop()

        // Step 1: Wait for connect.challenge event from server
        let challenge = try await waitForEvent(named: "connect.challenge", timeout: 5.0)
        let nonce = (challenge.payload?.value as? [String: Any])?["nonce"] as? String

        Self.logger.info("Received challenge, nonce: \(nonce ?? "nil")")

        // Step 2: Send connect request
        let connectId = UUID().uuidString
        var authParams: [String: Any] = [:]
        if let token {
            authParams["token"] = token
        }

        let connectParams: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 3,
            "client": [
                "id": "openclaw-macos",
                "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                "platform": "macos",
                "mode": "ui",
                "displayName": "Sable"
            ] as [String: Any],
            "role": "operator",
            "scopes": ["operator.read", "operator.write"],
            "auth": authParams
        ]
        // device is optional — only include if we have full device identity (id, publicKey, signature, signedAt, nonce)
        // For now we omit it; token-based auth is sufficient for local gateway
        _ = nonce // acknowledged but not used without full device identity

        try await sendRequest(id: connectId, method: "connect", params: connectParams)

        // Step 3: Wait for response
        let response = try await waitForResponse(id: connectId, timeout: 10.0)

        guard response.ok == true else {
            let msg = response.error?.message ?? "unknown"
            throw ACPError.handshakeFailed(msg)
        }

        isConnected = true
        Self.logger.info("ACP handshake complete")
    }

    // MARK: - Send Agent Request (Streaming)

    /// Attachment to send alongside an agent message (e.g. images).
    struct MessageAttachment: Sendable {
        let type: String       // "image"
        let mimeType: String   // "image/jpeg"
        let content: String    // base64-encoded data
        let fileName: String
    }

    /// Send a message to the agent and return a stream of events.
    func sendAgentMessage(
        _ message: String,
        sessionKey: String,
        attachments: [MessageAttachment] = []
    ) -> (requestId: String, stream: AsyncStream<StreamEvent>) {
        let requestId = UUID().uuidString
        let idempotencyKey = UUID().uuidString

        let stream = AsyncStream<StreamEvent> { continuation in
            Task { @MainActor in
                // Set up event handler to forward chat events
                self.eventHandler = { [weak self] frame in
                    guard frame.type == "event", frame.event == "chat" else { return }
                    guard let payload = frame.payload?.value as? [String: Any] else { return }

                    let state = payload["state"] as? String ?? ""

                    if state == "delta" {
                        let text = Self.extractText(from: payload)
                        let seq = payload["seq"] as? Int ?? 0
                        if !text.isEmpty {
                            continuation.yield(.delta(text: text, seq: seq))
                        }
                    } else if state == "final" {
                        let text = Self.extractText(from: payload)
                        let usageDict = payload["usage"] as? [String: Any]
                        let usage = StreamEvent.Usage(
                            inputTokens: usageDict?["inputTokens"] as? Int,
                            outputTokens: usageDict?["outputTokens"] as? Int
                        )
                        continuation.yield(.final_(text: text, usage: usage))
                        continuation.finish()
                        self?.eventHandler = nil
                    } else if state == "error" || state == "aborted" {
                        let errorMsg = payload["errorMessage"] as? String ?? "Agent error"
                        continuation.yield(.error(errorMsg))
                        continuation.finish()
                        self?.eventHandler = nil
                    }
                }

                // Send the agent request
                var params: [String: Any] = [
                    "message": message,
                    "sessionKey": sessionKey,
                    "idempotencyKey": idempotencyKey
                ]

                // Attach images if present
                if !attachments.isEmpty {
                    params["attachments"] = attachments.map { att in
                        [
                            "type": att.type,
                            "mimeType": att.mimeType,
                            "content": att.content,
                            "fileName": att.fileName
                        ] as [String: Any]
                    }
                }

                do {
                    try await self.sendRequest(id: requestId, method: "agent", params: params)

                    // Also watch for the agent response frame — if it contains an error
                    // (e.g. invalid params), surface it immediately
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        do {
                            let response = try await self.waitForResponse(id: requestId, timeout: 120.0)
                            // If agent responded with error (e.g. validation failure)
                            if response.ok != true {
                                let msg = response.error?.message ?? "Agent request failed"
                                continuation.yield(.error(msg))
                                continuation.finish()
                                self.eventHandler = nil
                            }
                            // If ok == true, the result comes via chat events — handled by eventHandler
                        } catch {
                            // Timeout or decode error — chat events may still be flowing, don't abort
                            Self.logger.warning("Agent response wait error (non-fatal): \(error.localizedDescription)")
                        }
                    }
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                    self.eventHandler = nil
                }
            }
        }

        return (requestId, stream)
    }

    // MARK: - Disconnect

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session?.invalidateAndCancel()
        session = nil
        isConnected = false
        eventHandler = nil
        pendingContinuations.values.forEach {
            $0.resume(throwing: ACPError.notConnected)
        }
        pendingContinuations.removeAll()
    }

    var connected: Bool { isConnected }

    // MARK: - Frame I/O

    private func sendRequest(id: String, method: String, params: [String: Any]) async throws {
        guard let ws = webSocket else { throw ACPError.notConnected }

        let frame: [String: Any] = [
            "type": "req",
            "id": id,
            "method": method,
            "params": params
        ]

        let data = try JSONSerialization.data(withJSONObject: frame)
        let string = String(data: data, encoding: .utf8) ?? ""
        try await ws.send(.string(string))
    }

    private func startReceiveLoop() {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let ws = self.webSocket else { break }
                do {
                    let message = try await ws.receive()
                    self.handleMessage(message)
                } catch {
                    Self.logger.error("WebSocket receive error: \(error.localizedDescription)")
                    await MainActor.run {
                        self.isConnected = false
                    }
                    break
                }
            }
        }
    }

    @MainActor
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let jsonString: String
        switch message {
        case .string(let text):
            jsonString = text
        case .data(let data):
            jsonString = String(data: data, encoding: .utf8) ?? ""
        @unknown default:
            return
        }

        guard let data = jsonString.data(using: .utf8),
              let frame = try? JSONDecoder().decode(Frame.self, from: data) else {
            Self.logger.warning("Failed to decode frame: \(jsonString.prefix(200))")
            return
        }

        // Route response frames to pending continuations
        if frame.type == "res", let id = frame.id, let cont = pendingContinuations.removeValue(forKey: id) {
            cont.resume(returning: frame)
            return
        }

        // Route event frames
        if frame.type == "event" {
            // Check pending event waiters
            if let eventName = frame.event, let cont = pendingContinuations.removeValue(forKey: "event:\(eventName)") {
                cont.resume(returning: frame)
                return
            }
            // Forward to active event handler
            eventHandler?(frame)
        }
    }

    // MARK: - Waiting Helpers

    private func waitForResponse(id: String, timeout: TimeInterval) async throws -> Frame {
        try await withCheckedThrowingContinuation { continuation in
            pendingContinuations[id] = continuation

            Task {
                try? await Task.sleep(for: .seconds(timeout))
                await MainActor.run {
                    if let cont = self.pendingContinuations.removeValue(forKey: id) {
                        cont.resume(throwing: ACPError.timeout)
                    }
                }
            }
        }
    }

    private func waitForEvent(named eventName: String, timeout: TimeInterval) async throws -> Frame {
        try await withCheckedThrowingContinuation { continuation in
            pendingContinuations["event:\(eventName)"] = continuation

            Task {
                try? await Task.sleep(for: .seconds(timeout))
                await MainActor.run {
                    if let cont = self.pendingContinuations.removeValue(forKey: "event:\(eventName)") {
                        cont.resume(throwing: ACPError.timeout)
                    }
                }
            }
        }
    }

    // MARK: - Text Extraction

    private static func extractText(from payload: [String: Any]) -> String {
        // Gateway format: message.content is an array of {type: "text", text: "..."}
        if let message = payload["message"] as? [String: Any],
           let content = message["content"] as? [[String: Any]] {
            return content
                .filter { ($0["type"] as? String) == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
        }
        // Fallback: message.text (legacy)
        if let message = payload["message"] as? [String: Any],
           let text = message["text"] as? String {
            return text
        }
        // Fallback: payload.text directly
        if let text = payload["text"] as? String {
            return text
        }
        return ""
    }
}

// MARK: - AnyCodable (minimal, for decoding arbitrary JSON)

struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
