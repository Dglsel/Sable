import SwiftUI

/// Editor for HEARTBEAT.md — task list UI + raw markdown editor.
/// Owns tasks and draft @State; pushes markdown content + dirty flag to parent via callback.
struct HeartbeatEditorView: View {
    let diskContent: String
    var onContentUpdate: (String, Bool) -> Void

    @State private var tasks: [String] = []
    @State private var newTask = ""
    @State private var draft = ""

    private var isDirty: Bool {
        draft != diskContent
    }

    var body: some View {
        VStack(spacing: 0) {
            // Quick-add task bar
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                TextField("Add a heartbeat task…", text: $newTask)
                    .textFieldStyle(.plain)
                    .font(SableTypography.labelSmall)
                    .onSubmit { addTask() }
                Button("Add") { addTask() }
                    .font(SableTypography.caption)
                    .disabled(newTask.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Task list (parsed from markdown)
            if !tasks.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                            taskRow(index: index, task: task)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 200)

                Divider()
            }

            // Raw editor below
            TextEditor(text: $draft)
                .font(.system(size: 12.5, design: .monospaced))
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            statusBar
        }
        .onAppear { load(from: diskContent) }
        .onChange(of: diskContent) { _, newValue in load(from: newValue) }
        .onChange(of: draft) { _, _ in onContentUpdate(draft, isDirty) }
    }

    // MARK: - Task Management

    private func taskRow(index: Int, task: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(SableTheme.success)
            Text(task)
                .font(SableTypography.labelSmall)
                .lineLimit(2)
            Spacer()
            Button {
                removeTask(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func addTask() {
        let trimmed = newTask.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        tasks.append(trimmed)
        newTask = ""
        draft = buildMarkdown()
    }

    private func removeTask(at index: Int) {
        guard tasks.indices.contains(index) else { return }
        tasks.remove(at: index)
        draft = buildMarkdown()
    }

    // MARK: - Parse & Build

    private func load(from markdown: String) {
        draft = markdown
        tasks = markdown.components(separatedBy: .newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- [ ] ") { return String(trimmed.dropFirst(6)) }
                if trimmed.hasPrefix("- [x] ") { return String(trimmed.dropFirst(6)) }
                if trimmed.hasPrefix("- ") && !trimmed.hasPrefix("- **") {
                    let content = String(trimmed.dropFirst(2))
                    if content.hasPrefix("#") || content.isEmpty { return nil }
                    return content
                }
                return nil
            }
    }

    private func buildMarkdown() -> String {
        var lines = ["# HEARTBEAT.md", ""]
        if tasks.isEmpty {
            lines.append("# Keep this file empty (or with only comments) to skip heartbeat API calls.")
            lines.append("")
            lines.append("# Add tasks below when you want the agent to check something periodically.")
        } else {
            for task in tasks {
                lines.append("- \(task)")
            }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private var statusBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Text("\(draft.components(separatedBy: .newlines).count) lines")
                Text("\(draft.count) chars")
                Spacer()
                Text("⌘S to save")
            }
            .font(SableTypography.micro)
            .foregroundStyle(.quaternary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
    }
}
