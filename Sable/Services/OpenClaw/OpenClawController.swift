import Foundation

/// Manages OpenClaw gateway lifecycle (start / stop / restart).
/// All operations are async and return a result with stdout/stderr output.
struct OpenClawController: Sendable {

    struct CommandResult: Sendable {
        let success: Bool
        let output: String
    }

    // MARK: - Public API

    func start() async -> CommandResult {
        // Try LaunchAgent first, fall back to direct gateway launch.
        let plistPath = launchAgentPlistPath()

        if FileManager.default.fileExists(atPath: plistPath) {
            return await runShell(
                "/bin/launchctl",
                arguments: ["bootstrap", "gui/\(getuid())", plistPath]
            )
        }

        // Fallback: find openclaw binary and launch gateway directly.
        guard let binary = await findBinary() else {
            return CommandResult(success: false, output: "openclaw binary not found.")
        }

        return await runShell(binary, arguments: ["gateway"])
    }

    func stop() async -> CommandResult {
        let plistPath = launchAgentPlistPath()

        if FileManager.default.fileExists(atPath: plistPath) {
            return await runShell(
                "/bin/launchctl",
                arguments: ["bootout", "gui/\(getuid())", plistPath]
            )
        }

        // Fallback: pkill
        return await runShell("/usr/bin/pkill", arguments: ["-f", "openclaw.*gateway"])
    }

    func restart() async -> CommandResult {
        let stopResult = await stop()
        // Brief pause for process cleanup.
        try? await Task.sleep(for: .seconds(2))
        let startResult = await start()

        if startResult.success {
            return startResult
        }

        let combinedOutput = [stopResult.output, startResult.output]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return CommandResult(success: false, output: combinedOutput)
    }

    // MARK: - Internals

    private func launchAgentPlistPath() -> String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/ai.openclaw.gateway.plist")
            .path
    }

    private func findBinary() async -> String? {
        let knownPaths = [
            "/opt/homebrew/bin/openclaw",
            "/usr/local/bin/openclaw"
        ]

        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try `which`
        let result = await runShell("/usr/bin/which", arguments: ["openclaw"])
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.success && !path.isEmpty ? path : nil
    }

    private func runShell(_ command: String, arguments: [String] = []) async -> CommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: command)
                process.arguments = arguments

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                // Read pipes before waitUntilExit to prevent deadlock on large output
                var outData = Data()
                var errData = Data()
                let outQueue = DispatchQueue(label: "sable.ctrl.stdout")
                let errQueue = DispatchQueue(label: "sable.ctrl.stderr")
                outQueue.async { outData = outPipe.fileHandleForReading.readDataToEndOfFile() }
                errQueue.async { errData = errPipe.fileHandleForReading.readDataToEndOfFile() }

                do {
                    try process.run()
                    process.waitUntilExit()
                    outQueue.sync {}
                    errQueue.sync {}

                    let out = String(data: outData, encoding: .utf8) ?? ""
                    let err = String(data: errData, encoding: .utf8) ?? ""
                    let combined = [out, err]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n")

                    continuation.resume(returning: CommandResult(
                        success: process.terminationStatus == 0,
                        output: combined
                    ))
                } catch {
                    continuation.resume(returning: CommandResult(
                        success: false,
                        output: error.localizedDescription
                    ))
                }
            }
        }
    }
}
