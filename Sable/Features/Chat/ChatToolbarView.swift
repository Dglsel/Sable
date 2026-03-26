import SwiftUI

struct ChatToolbarView: View {
    @Environment(AppState.self) private var appState

    @State private var agentName: String = "OpenClaw"
    @State private var modelName: String = ""

    private static let defaultAgentName = "OpenClaw"

    var body: some View {
        HStack(spacing: 10) {
            // Agent identity (primary)
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SableTheme.interactive)
                Text(agentName)
                    .font(SableTypography.subtitle)
                    .lineLimit(1)
            }

            // Model (secondary, dimmer)
            if !modelName.isEmpty {
                Text("·")
                    .font(SableTypography.caption)
                    .foregroundStyle(.quaternary)
                Text(modelName)
                    .font(SableTypography.mono)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .onAppear { loadInfo() }
    }

    // MARK: - Data Loading

    private func loadInfo() {
        if let identity = WorkspaceService.read(.identity) {
            let name = extractField("Name", from: identity)
            if isValidAgentName(name) {
                agentName = name
            }
        }

        let config = OpenClawConfig.readFromDisk()
        if let model = config.primaryModel, !model.isEmpty {
            modelName = model
        }
    }

    // MARK: - Parsing

    /// Parses `- **Field:** value` on a single line only.
    private func extractField(_ field: String, from markdown: String) -> String {
        for line in markdown.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let prefix = "- **\(field):**"
            if trimmed.hasPrefix(prefix) {
                let value = String(trimmed.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
                return value
            }
        }
        return ""
    }

    /// Rejects empty, whitespace-only, placeholder, and template text.
    private func isValidAgentName(_ name: String) -> Bool {
        let cleaned = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            // Strip surrounding markdown italics/underscores
            .trimmingCharacters(in: CharacterSet(charactersIn: "_*"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if cleaned.isEmpty { return false }

        let placeholders = [
            "pick something",
            "your name",
            "agent name",
            "fill in",
            "todo",
            "tbd",
            "placeholder",
            "example",
            "untitled",
        ]

        for placeholder in placeholders {
            if cleaned.contains(placeholder) { return false }
        }

        // Reject if the whole value is wrapped in parens (template hint)
        let parenStripped = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if parenStripped.hasPrefix("(") && parenStripped.hasSuffix(")") { return false }
        if parenStripped.hasPrefix("_(") && parenStripped.hasSuffix(")_") { return false }

        return true
    }
}
