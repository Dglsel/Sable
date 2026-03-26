import Foundation

/// Reads and writes `~/.openclaw/openclaw.json`, the single source of truth for OpenClaw configuration.
struct OpenClawConfig: Equatable {

    /// The primary model identifier, e.g. `"openai-codex/gpt-5.4"`.
    let primaryModel: String?

    /// All configured model identifiers (keys from `agents.defaults.models`).
    let configuredModels: [String]

    /// Authenticated provider profiles (e.g. `"openai-codex"` with mode `"oauth"`).
    let authProfiles: [AuthProfile]

    /// Gateway connection details.
    let gateway: GatewayConfig

    struct AuthProfile: Equatable, Identifiable {
        let id: String          // profile key, e.g. "openai-codex:default"
        let provider: String    // e.g. "openai-codex"
        let mode: String        // e.g. "oauth", "api-key"
    }

    // MARK: - File Path

    static var configFileURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw")
            .appendingPathComponent("openclaw.json")
    }

    // MARK: - Read

    static func readFromDisk() -> OpenClawConfig {
        guard let data = try? Data(contentsOf: configFileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .empty
        }
        return parse(json)
    }

    // MARK: - Write Primary Model

    /// Updates `agents.defaults.model.primary` in `openclaw.json` and returns the updated config.
    /// Also auto-configures `tools.web.search` based on the provider so web search works out of the box.
    @discardableResult
    static func writePrimaryModel(_ modelID: String) -> OpenClawConfig? {
        guard let data = try? Data(contentsOf: configFileURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Navigate to agents.defaults.model and set primary
        var agents = json["agents"] as? [String: Any] ?? [:]
        var defaults = agents["defaults"] as? [String: Any] ?? [:]
        var model = defaults["model"] as? [String: Any] ?? [:]
        model["primary"] = modelID
        defaults["model"] = model
        agents["defaults"] = defaults
        json["agents"] = agents

        // Auto-configure web search provider based on model provider.
        // Providers with native search: kimi (moonshot), gemini, grok.
        // This reuses the existing API key — no extra config needed from the user.
        if let searchProvider = searchProvider(for: modelID) {
            var tools = json["tools"] as? [String: Any] ?? [:]
            var web = tools["web"] as? [String: Any] ?? [:]
            web["search"] = [
                "enabled": true,
                "provider": searchProvider
            ] as [String: Any]
            tools["web"] = web
            json["tools"] = tools
        }

        // Write back atomically
        guard let updatedData = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return nil }

        try? updatedData.write(to: configFileURL, options: .atomic)
        return readFromDisk()
    }

    /// Maps a model ID (e.g. "moonshot/kimi-k2.5") to a gateway-supported search provider.
    /// Returns nil if the provider has no native search backend.
    private static func searchProvider(for modelID: String) -> String? {
        let prefix = modelID.split(separator: "/").first.map(String.init)?.lowercased() ?? modelID.lowercased()
        switch prefix {
        case "moonshot", "kimi":
            return "kimi"
        case "gemini", "google":
            return "gemini"
        case "grok", "x-ai", "xai":
            return "grok"
        default:
            return nil
        }
    }

    // MARK: - Parsing

    private static func parse(_ json: [String: Any]) -> OpenClawConfig {
        // agents.defaults.model.primary
        let agents = json["agents"] as? [String: Any] ?? [:]
        let defaults = agents["defaults"] as? [String: Any] ?? [:]
        let modelSection = defaults["model"] as? [String: Any] ?? [:]
        let primaryModel = modelSection["primary"] as? String

        // agents.defaults.models (keys are model IDs)
        let modelsDict = defaults["models"] as? [String: Any] ?? [:]
        let configuredModels = Array(modelsDict.keys).sorted()

        // auth.profiles
        let auth = json["auth"] as? [String: Any] ?? [:]
        let profilesDict = auth["profiles"] as? [String: Any] ?? [:]
        let authProfiles: [AuthProfile] = profilesDict.compactMap { key, value in
            guard let profile = value as? [String: Any] else { return nil }
            return AuthProfile(
                id: key,
                provider: profile["provider"] as? String ?? key,
                mode: profile["mode"] as? String ?? "unknown"
            )
        }.sorted { $0.provider < $1.provider }

        // gateway (with correct nested auth.token path)
        let gatewayDict = json["gateway"] as? [String: Any] ?? [:]
        let host = (gatewayDict["host"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let port = gatewayDict["port"] as? Int

        let token: String? = {
            // Primary path: gateway.auth.token
            if let gatewayAuth = gatewayDict["auth"] as? [String: Any],
               let t = gatewayAuth["token"] as? String {
                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            // Fallback: gateway.token (legacy)
            if let t = gatewayDict["token"] as? String {
                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            return nil
        }()

        let gateway = GatewayConfig(
            host: (host?.isEmpty == false) ? host! : GatewayConfig.defaultHost,
            port: port.flatMap { UInt16(exactly: $0) } ?? GatewayConfig.defaultPort,
            token: token,
            primaryModel: primaryModel
        )

        return OpenClawConfig(
            primaryModel: primaryModel,
            configuredModels: configuredModels,
            authProfiles: authProfiles,
            gateway: gateway
        )
    }

    static let empty = OpenClawConfig(
        primaryModel: nil,
        configuredModels: [],
        authProfiles: [],
        gateway: GatewayConfig(
            host: GatewayConfig.defaultHost,
            port: GatewayConfig.defaultPort,
            token: nil,
            primaryModel: nil
        )
    )
}
