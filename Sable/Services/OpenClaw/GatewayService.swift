import Foundation
import os

/// Sends chat messages to the local OpenClaw gateway.
///
/// Two paths:
/// 1. **Streaming (preferred)**: Direct WebSocket via ACP protocol — block-level incremental updates.
/// 2. **CLI fallback**: `openclaw agent --json` subprocess — one-shot response.
@MainActor
final class GatewayService {

    private static let logger = Logger(subsystem: "ai.sable", category: "GatewayService")

    // MARK: - Errors

    enum GatewayError: LocalizedError {
        case notInstalled
        case notInitialized
        case gatewayNotRunning
        case binaryNotFound
        case commandFailed(exitCode: Int32, stderr: String)
        case decodingFailed(raw: String)
        case emptyResponse
        case timeout

        var errorDescription: String? { errorSummary }

        /// Human-readable summary (shown prominently in ErrorBlockView).
        var errorSummary: String {
            switch self {
            case .notInstalled:
                "OpenClaw is not installed."
            case .notInitialized:
                "OpenClaw needs initial setup."
            case .gatewayNotRunning:
                "Gateway is not running."
            case .binaryNotFound:
                "Cannot find the openclaw binary."
            case .commandFailed:
                "Agent command failed."
            case .decodingFailed:
                "Could not parse agent response."
            case .emptyResponse:
                "Agent returned an empty response."
            case .timeout:
                "Request timed out."
            }
        }

        /// Technical detail (collapsible in ErrorBlockView).
        var errorDetail: String? {
            switch self {
            case .notInstalled:
                "Go to Dashboard to install OpenClaw."
            case .notInitialized:
                "Go to Dashboard to complete onboarding."
            case .gatewayNotRunning:
                "Start the gateway from the Dashboard, then try again."
            case .binaryNotFound:
                "Checked /opt/homebrew/bin/openclaw, /usr/local/bin/openclaw, and $PATH. Reinstall or verify your PATH."
            case .commandFailed(let code, let stderr):
                "Exit code \(code)\n\(stderr)"
            case .decodingFailed(let raw):
                "Raw response:\n\(String(raw.prefix(500)))"
            case .emptyResponse:
                nil
            case .timeout:
                "The agent did not respond within 120 seconds. The gateway may be overloaded."
            }
        }

        /// Whether the user can meaningfully retry this error.
        var isRetryable: Bool {
            switch self {
            case .gatewayNotRunning, .timeout, .commandFailed, .emptyResponse:
                true
            case .notInstalled, .notInitialized, .binaryNotFound, .decodingFailed:
                false
            }
        }

        /// Convert to a structured ErrorBlock for rendering.
        var asErrorBlock: ErrorBlock {
            ErrorBlock(summary: errorSummary, technicalDetail: errorDetail, isRetryable: isRetryable)
        }
    }

    // MARK: - Dependencies

    private let openClawService: OpenClawService
    private let responsesService = OpenResponsesService()

    init(openClawService: OpenClawService) {
        self.openClawService = openClawService
    }

    // MARK: - Streaming Path (HTTP /v1/responses + SSE)

    /// Send a message via OpenResponses HTTP API with SSE streaming.
    /// Supports text and image/file attachments natively.
    func sendMessageStreaming(
        _ prompt: String,
        context: Conversation,
        attachments: [OpenResponsesService.Attachment] = []
    ) async throws -> AsyncStream<OpenResponsesService.StreamEvent> {
        try validateStatus()

        let config = GatewayConfig.readFromDisk()
        let model = config.primaryModel ?? "moonshot/kimi-k2.5"
        let conversationId = context.id.uuidString

        return try await responsesService.sendMessage(
            prompt,
            model: model,
            conversationId: conversationId,
            attachments: attachments,
            stream: true
        )
    }

    /// Cancel any in-flight streaming request.
    func cancelStreaming() {
        responsesService.cancelStreaming()
    }

    // MARK: - CLI Fallback Path (One-Shot)

    /// Sends a message through `openclaw agent` CLI and returns a structured response
    /// with timing metadata.
    func sendMessage(_ prompt: String, context: Conversation) async throws -> ParsedAgentResponse {
        // 1. Validate preconditions
        try validateStatus()

        guard let binary = Self.findBinary() else {
            throw GatewayError.binaryNotFound
        }

        // 2. Build session ID from conversation's persistent UUID
        let sessionID = "sable-\(context.id.uuidString.prefix(8).lowercased())"

        Self.logger.info("Sending message via CLI bridge: session=\(sessionID)")

        // 3. Execute `openclaw agent` with timing
        let startTime = CFAbsoluteTimeGetCurrent()

        let result = try await runAgent(
            binary: binary,
            sessionID: sessionID,
            message: prompt
        )

        let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        // 4. Parse JSON response
        let text = try parseAgentResponse(result)
        let metadata = ResponseMetadata(modelName: nil, tokenCount: nil, durationMs: durationMs)

        return ParsedAgentResponse(
            blocks: [.text(text)],
            plainText: text,
            metadata: metadata
        )
    }

    // MARK: - Precondition Checks

    private func validateStatus() throws {
        switch openClawService.status {
        case .notInstalled:
            throw GatewayError.notInstalled
        case .needsOnboarding:
            throw GatewayError.notInitialized
        case .installedStopped:
            throw GatewayError.gatewayNotRunning
        case .error(let msg):
            throw GatewayError.commandFailed(exitCode: -1, stderr: msg)
        case .running:
            break
        }
    }

    // MARK: - Binary Location

    static func findBinary() -> String? {
        // Direct filesystem check first (fastest, no subprocess)
        let knownPaths = [
            "/opt/homebrew/bin/openclaw",
            "/usr/local/bin/openclaw"
        ]
        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                Self.logger.info("Found openclaw at: \(path)")
                return path
            }
        }

        // Fallback: `which` with full PATH
        let whichResult = Self.runSyncCommand("/usr/bin/which", arguments: ["openclaw"])
        if let path = whichResult, !path.isEmpty {
            Self.logger.info("Found openclaw via which: \(path)")
            return path
        }

        Self.logger.error("openclaw binary not found")
        return nil
    }

    // MARK: - CLI Execution

    /// Builds a PATH that includes common binary locations for node, homebrew, etc.
    /// macOS GUI apps inherit a minimal PATH that typically lacks /opt/homebrew/bin,
    /// causing `openclaw` (a Node.js script) to fail with "env: node: No such file or directory".
    private static func buildFullPATH() -> String {
        // Start with the GUI app's existing PATH (usually very short)
        let existing = ProcessInfo.processInfo.environment["PATH"] ?? ""

        // Essential paths that must be present for openclaw + node to work
        let requiredPaths = [
            "/opt/homebrew/bin",       // Apple Silicon homebrew (node, openclaw)
            "/opt/homebrew/sbin",
            "/usr/local/bin",          // Intel homebrew / manual installs
            "/usr/local/sbin",
            "/usr/bin",
            "/usr/sbin",
            "/bin",
            "/sbin"
        ]

        // Also try to read the user's shell PATH for any custom locations (nvm, volta, etc.)
        let userPaths = shellPATH() ?? ""

        // Merge: user shell paths + required + existing (deduplicated, order preserved)
        var seen = Set<String>()
        var merged: [String] = []
        for path in (userPaths.split(separator: ":").map(String.init) + requiredPaths + existing.split(separator: ":").map(String.init)) {
            guard !path.isEmpty, !seen.contains(path) else { continue }
            seen.insert(path)
            merged.append(path)
        }

        return merged.joined(separator: ":")
    }

    /// Attempts to read the user's login shell PATH by running `$SHELL -l -c 'echo $PATH'`.
    /// Returns nil if it fails (non-blocking, best effort).
    private static func shellPATH() -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-c", "echo $PATH"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        var data = Data()
        let readQueue = DispatchQueue(label: "sable.shell.stdout")
        readQueue.async { data = pipe.fileHandleForReading.readDataToEndOfFile() }
        do {
            try process.run()
            process.waitUntilExit()
            readQueue.sync {}
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Cached full PATH, computed once at first use.
    private static let fullPATH: String = buildFullPATH()

    /// Builds a subprocess environment with full PATH and proxy bypass.
    static func buildSubprocessEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = fullPATH
        let noProxy = env["NO_PROXY"] ?? env["no_proxy"] ?? ""
        if !noProxy.contains("127.0.0.1") {
            env["NO_PROXY"] = noProxy.isEmpty ? "127.0.0.1,localhost" : "\(noProxy),127.0.0.1,localhost"
        }
        return env
    }

    /// Runs `openclaw agent --session-id <id> --message <text> --json --timeout 120`
    /// in a subprocess and returns the combined stdout output.
    private func runAgent(binary: String, sessionID: String, message: String) async throws -> String {
        let environment = Self.buildSubprocessEnvironment()
        let logger = Self.logger
        let fullPATH = Self.fullPATH

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: binary)
                process.arguments = [
                    "agent",
                    "--session-id", sessionID,
                    "--message", message,
                    "--json",
                    "--timeout", "120"
                ]

                process.environment = environment

                logger.info("CLI PATH: \(fullPATH.prefix(200))")

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                // Read pipes on background queues BEFORE waitUntilExit to prevent
                // deadlock when output exceeds the ~64KB pipe buffer.
                var stdoutData = Data()
                var stderrData = Data()
                let stdoutQueue = DispatchQueue(label: "sable.gateway.stdout")
                let stderrQueue = DispatchQueue(label: "sable.gateway.stderr")

                stdoutQueue.async {
                    stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                }
                stderrQueue.async {
                    stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: GatewayError.binaryNotFound)
                    return
                }

                process.waitUntilExit()

                // Wait for pipe readers to finish
                stdoutQueue.sync {}
                stderrQueue.sync {}

                let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                logger.info("CLI exit code: \(process.terminationStatus), stdout length: \(stdout.count)")

                if process.terminationStatus != 0 {
                    // Check for common failure patterns
                    let combined = "\(stdout) \(stderr)"
                    if combined.contains("not found") || combined.contains("ENOENT") {
                        continuation.resume(throwing: GatewayError.binaryNotFound)
                    } else if combined.contains("gateway") && combined.contains("connect") {
                        continuation.resume(throwing: GatewayError.gatewayNotRunning)
                    } else {
                        continuation.resume(throwing: GatewayError.commandFailed(
                            exitCode: process.terminationStatus,
                            stderr: stderr.isEmpty ? stdout : stderr
                        ))
                    }
                    return
                }

                continuation.resume(returning: stdout)
            }
        }
    }

    // MARK: - Response Parsing

    /// Parses the JSON output from `openclaw agent --json`.
    /// Expected format:
    /// ```json
    /// {
    ///   "status": "ok",
    ///   "result": {
    ///     "payloads": [{ "text": "...", "mediaUrl": null }]
    ///   }
    /// }
    /// ```
    private func parseAgentResponse(_ raw: String) throws -> String {
        guard !raw.isEmpty else {
            throw GatewayError.emptyResponse
        }

        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GatewayError.decodingFailed(raw: raw)
        }

        // Check status
        if let status = json["status"] as? String, status != "ok" {
            let summary = json["summary"] as? String ?? "unknown error"
            throw GatewayError.commandFailed(exitCode: 1, stderr: summary)
        }

        // Extract text from result.payloads[0].text
        guard let result = json["result"] as? [String: Any],
              let payloads = result["payloads"] as? [[String: Any]],
              let firstPayload = payloads.first,
              let text = firstPayload["text"] as? String else {
            throw GatewayError.decodingFailed(raw: raw)
        }

        guard !text.isEmpty else {
            throw GatewayError.emptyResponse
        }

        return text
    }

    // MARK: - Shell Helper

    private static func runSyncCommand(_ command: String, arguments: [String] = []) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        var data = Data()
        let readQueue = DispatchQueue(label: "sable.sync.stdout")
        readQueue.async { data = pipe.fileHandleForReading.readDataToEndOfFile() }

        do {
            try process.run()
            process.waitUntilExit()
            readQueue.sync {}
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
