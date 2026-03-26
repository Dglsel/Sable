import SwiftUI

/// Shared form components for Agent editor forms (Identity, User).
/// Internal to the Agents feature — not global components.

// MARK: - Structured Form Field

struct StructuredFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)
                Text(label)
                    .font(SableTypography.captionMedium)
                    .foregroundStyle(.secondary)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(SableTypography.body)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                        .strokeBorder(SableTheme.border)
                )
        }
    }
}

// MARK: - Raw Markdown Preview

struct RawMarkdownPreview: View {
    let content: String

    var body: some View {
        DisclosureGroup {
            Text(content)
                .font(SableTypography.mono)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(SableTheme.bgTertiary.opacity(0.3), in: RoundedRectangle(cornerRadius: SableRadius.md))
        } label: {
            Text("Raw Markdown Preview")
                .font(SableTypography.captionMedium)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Markdown Field Parser

enum MarkdownFieldParser {

    /// Extracts a field value like `- **Name:** value` from markdown.
    static func extractField(_ field: String, from markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            if line.contains("**\(field):**") {
                let parts = line.components(separatedBy: "**\(field):**")
                if parts.count > 1 {
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty && !value.hasPrefix("_(") {
                        return value
                    }
                }
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
                    if !nextLine.isEmpty && !nextLine.hasPrefix("- **") && !nextLine.hasPrefix("_(") && !nextLine.hasPrefix("---") {
                        return nextLine
                    }
                }
            }
        }
        return ""
    }

    /// Extracts the content under `## Context` heading.
    static func extractContextSection(from markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        guard let contextIndex = lines.firstIndex(where: { $0.hasPrefix("## Context") }) else {
            return ""
        }

        var result: [String] = []
        for i in (contextIndex + 1)..<lines.count {
            let line = lines[i]
            if line.hasPrefix("## ") || line.hasPrefix("---") { break }
            result.append(line)
        }

        let joined = result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if joined.hasPrefix("_(") && joined.hasSuffix(")_") { return "" }
        return joined
    }
}
