import SwiftUI

/// Editor for a single Agent workspace file.
/// Identity and User get structured forms; others get text editors.
/// All editors share: load from disk, local draft, save to disk, dirty indicator.
struct AgentEditorView: View {
    let section: AgentSection
    @Binding var isDirtyBinding: Bool
    @Binding var saveTrigger: Bool
    var onSaveCompleted: (() -> Void)?

    @State private var draft = ""
    @State private var diskContent = ""
    @State private var saveStatus: SaveStatus = .idle
    @State private var isLoaded = false
    @State private var showGuide = false

    // Identity (child-push)
    @State private var identityContent = ""
    @State private var identityDirty = false

    // User (child-push)
    @State private var userContent = ""
    @State private var userDirty = false

    // Heartbeat (child-push)
    @State private var heartbeatContent = ""
    @State private var heartbeatDirty = false

    private enum SaveStatus: Equatable {
        case idle, saving, saved, error(String)
    }

    private var isDirty: Bool {
        guard isLoaded else { return false }
        switch section {
        case .identity: return identityDirty
        case .user: return userDirty
        case .heartbeat: return heartbeatDirty
        default: return draft != diskContent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            editorToolbar
            Divider()
            if showGuide {
                sectionGuideCard
            }
            editorContent
        }
        .onAppear {
            loadFromDisk()
            isDirtyBinding = false
        }
        .onChange(of: section) { _, _ in
            showGuide = false
            loadFromDisk()
            isDirtyBinding = false
        }
        .onChange(of: isDirty) { _, newValue in
            isDirtyBinding = newValue
        }
        .onChange(of: saveTrigger) { _, newValue in
            guard newValue else { return }
            saveTrigger = false
            save()
            onSaveCompleted?()
        }
    }

    // MARK: - Toolbar

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text(section.label)
                    .font(SableTypography.title)
                Text(section.fileName)
                    .font(SableTypography.mono)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isDirty {
                Text("Unsaved changes")
                    .font(SableTypography.caption)
                    .foregroundStyle(SableTheme.warning)
            }

            saveStatusView

            Button {
                withAnimation(SableAnimation.enter()) {
                    showGuide.toggle()
                }
            } label: {
                Image(systemName: showGuide ? "info.circle.fill" : "info.circle")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(showGuide ? .primary : .secondary)
            .help("Section guide")

            Button {
                revert()
            } label: {
                Label("Revert", systemImage: "arrow.uturn.backward")
                    .font(SableTypography.labelSmall)
            }
            .disabled(!isDirty)

            Button {
                save()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
                    .font(SableTypography.labelSmall)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!isDirty || saveStatus == .saving)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Section Guide

    private var sectionGuideCard: some View {
        let guide = section.guide

        return HStack(alignment: .top, spacing: 0) {
            Text(guide.what)
                .font(SableTypography.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            Spacer(minLength: 16)

            Text(guide.versus)
                .font(SableTypography.micro)
                .foregroundStyle(.secondary.opacity(0.6))
                .lineSpacing(2)
                .frame(maxWidth: 200, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.015))
        .transition(.opacity.animation(SableAnimation.enter(duration: SableAnimation.fast)))
    }

    // MARK: - Editor Content

    @ViewBuilder
    private var editorContent: some View {
        if !isLoaded {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch section {
            case .identity: identityFormView
            case .user: userFormView
            case .heartbeat: heartbeatEditorView
            case .tools: toolsEditor
            default: markdownEditor
            }
        }
    }

    // MARK: - Identity (delegated to IdentityFormView)

    private var identityFormView: some View {
        IdentityFormView(diskContent: diskContent) { content, dirty in
            identityContent = content
            identityDirty = dirty
        }
    }

    // MARK: - User (delegated to UserFormView)

    private var userFormView: some View {
        UserFormView(diskContent: diskContent) { content, dirty in
            userContent = content
            userDirty = dirty
        }
    }

    // MARK: - Tools Editor (enhanced text editor with template hint)

    private var toolsEditor: some View {
        VStack(spacing: 0) {
            TextEditor(text: $draft)
                .font(SableTypography.codeBlock)
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            editorStatusBar
        }
    }

    // MARK: - Heartbeat (delegated to HeartbeatEditorView)

    private var heartbeatEditorView: some View {
        HeartbeatEditorView(diskContent: diskContent) { content, dirty in
            heartbeatContent = content
            heartbeatDirty = dirty
        }
    }

    // MARK: - Generic Markdown Editor (Soul, Instructions, Memory)

    private var markdownEditor: some View {
        VStack(spacing: 0) {
            TextEditor(text: $draft)
                .font(SableTypography.codeBlock)
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            editorStatusBar
        }
    }

    private var editorStatusBar: some View {
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

    // MARK: - Load / Save / Revert

    private func loadFromDisk() {
        let content = WorkspaceService.read(section) ?? ""
        diskContent = content
        draft = content
        saveStatus = .idle

        isLoaded = true
    }

    private func save() {
        saveStatus = .saving

        let content: String
        switch section {
        case .identity: content = identityContent
        case .user: content = userContent
        case .heartbeat: content = heartbeatContent
        default: content = draft
        }

        if WorkspaceService.write(section, content: content) {
            diskContent = content
            if section != .identity && section != .user && section != .heartbeat {
                draft = content
            }
            saveStatus = .saved
            Task {
                try? await Task.sleep(for: .seconds(2))
                if saveStatus == .saved { saveStatus = .idle }
            }
        } else {
            saveStatus = .error("Failed to save")
        }
    }

    private func revert() {
        draft = diskContent
        saveStatus = .idle
    }

    // MARK: - Save Status View

    @ViewBuilder
    private var saveStatusView: some View {
        switch saveStatus {
        case .idle:
            EmptyView()
        case .saving:
            ProgressView()
                .controlSize(.mini)
        case .saved:
            Label("Saved", systemImage: "checkmark")
                .font(SableTypography.caption)
                .foregroundStyle(SableTheme.success)
                .transition(.opacity)
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .font(SableTypography.caption)
                .foregroundStyle(SableTheme.error)
                .transition(.opacity)
        }
    }
}
