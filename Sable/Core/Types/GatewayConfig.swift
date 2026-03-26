import Foundation

/// Gateway connection parameters, read from `~/.openclaw/openclaw.json` with sensible defaults.
struct GatewayConfig: Equatable {
    let host: String
    let port: UInt16
    let token: String?
    /// Primary model from `agents.defaults.model.primary`, e.g. `"moonshot/kimi-k2.5"`.
    let primaryModel: String?

    var baseURL: URL? {
        URL(string: "http://\(host):\(port)")
    }

    var chatCompletionsURL: URL? {
        baseURL?.appendingPathComponent("v1/chat/completions")
    }

    static let defaultHost = "127.0.0.1"
    static let defaultPort: UInt16 = 18789

    /// Reads gateway config from `~/.openclaw/openclaw.json`.
    /// Falls back to defaults for any missing fields.
    static func readFromDisk() -> GatewayConfig {
        let configFile = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw")
            .appendingPathComponent("openclaw.json")

        guard let data = try? Data(contentsOf: configFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gateway = json["gateway"] as? [String: Any] else {
            return GatewayConfig(host: defaultHost, port: defaultPort, token: nil, primaryModel: nil)
        }

        let host = (gateway["host"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = gateway["port"] as? Int
        let token: String? = {
            // Primary path: gateway.auth.token
            if let gatewayAuth = gateway["auth"] as? [String: Any],
               let t = gatewayAuth["token"] as? String {
                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            // Fallback: gateway.token (legacy flat layout)
            if let t = gateway["token"] as? String {
                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            return nil
        }()

        // Read primary model from agents.defaults.model.primary
        let primaryModel: String? = {
            guard let agents = json["agents"] as? [String: Any],
                  let defaults = agents["defaults"] as? [String: Any],
                  let model = defaults["model"] as? [String: Any],
                  let primary = model["primary"] as? String else { return nil }
            return primary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : primary
        }()

        return GatewayConfig(
            host: (host?.isEmpty == false) ? host! : defaultHost,
            port: port.flatMap { UInt16(exactly: $0) } ?? defaultPort,
            token: token,
            primaryModel: primaryModel
        )
    }
}
