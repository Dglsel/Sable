import Foundation

/// Detects OpenClaw installation and runtime status without modifying any state.
struct OpenClawDetector: Sendable {

    /// Common binary locations on macOS.
    private static let binarySearchPaths = [
        "/opt/homebrew/bin/openclaw",
        "/usr/local/bin/openclaw"
    ]

    private static let configDirectory = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".openclaw")

    private static let workspaceDirectory = configDirectory
        .appendingPathComponent("workspace")

    private static let mainConfigFile = configDirectory
        .appendingPathComponent("openclaw.json")

    // MARK: - Public API

    func detect() async -> OpenClawStatus {
        guard let binaryPath = findBinary() else {
            return .notInstalled
        }

        let version = await queryVersion(binaryPath: binaryPath)

        guard isInitialized() else {
            return .needsOnboarding(version: version)
        }

        let gatewayReachable = await checkGateway()

        if gatewayReachable {
            return .running(version: version)
        } else {
            return .installedStopped(version: version)
        }
    }

    // MARK: - Binary Detection

    /// Checks `which openclaw` first, then falls back to known paths.
    private func findBinary() -> String? {
        if let whichResult = runSync(command: "/usr/bin/which", arguments: ["openclaw"]),
           !whichResult.isEmpty {
            return whichResult
        }

        for path in Self.binarySearchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    // MARK: - Initialization Check

    /// OpenClaw is considered initialized when both the config directory and
    /// workspace exist, **and** `openclaw.json` is present. Just having `~/.openclaw/`
    /// is not enough (npm may create stubs without completing onboard).
    private func isInitialized() -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false

        guard fm.fileExists(atPath: Self.configDirectory.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }

        guard fm.fileExists(atPath: Self.workspaceDirectory.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }

        guard fm.fileExists(atPath: Self.mainConfigFile.path) else {
            return false
        }

        return true
    }

    // MARK: - Version

    private func queryVersion(binaryPath: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = self.runSync(command: binaryPath, arguments: ["--version"])
                let version = result?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: version?.isEmpty == true ? nil : version)
            }
        }
    }

    // MARK: - Gateway Health

    /// Performs an HTTP health check against the gateway's `/health` endpoint.
    /// Uses a proxy-bypassing URLSession to avoid interference from system HTTP proxies.
    /// Returns true only when the gateway responds with `{"ok":true}`.
    private func checkGateway() async -> Bool {
        let port = OpenClawInstallHint.defaultGatewayPort
        let url = URL(string: "http://127.0.0.1:\(port)/health")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3

        do {
            let (data, response) = try await Self.proxyBypassSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            guard (200..<300).contains(http.statusCode) else { return false }

            // Verify the health response body contains "ok":true
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = json["ok"] as? Bool {
                return ok
            }
            return false
        } catch {
            // Connection refused / timeout = gateway not running
            return false
        }
    }

    /// A URLSession that bypasses system HTTP proxies.
    /// Required because many users run local VPN/proxy tools that intercept
    /// localhost connections and return 502.
    private static let proxyBypassSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: false,
            kCFNetworkProxiesHTTPSEnable: false
        ]
        config.timeoutIntervalForRequest = 3
        return URLSession(configuration: config)
    }()

    // MARK: - Shell Helper

    private func runSync(command: String, arguments: [String] = []) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        var data = Data()
        let readQueue = DispatchQueue(label: "sable.detect.stdout")
        readQueue.async { data = pipe.fileHandleForReading.readDataToEndOfFile() }

        do {
            try process.run()
            process.waitUntilExit()
            readQueue.sync {}

            guard process.terminationStatus == 0 else { return nil }

            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
