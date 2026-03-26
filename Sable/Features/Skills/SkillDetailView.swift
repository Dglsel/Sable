import SwiftUI

struct SkillDetailView: View {
    @Environment(\.colorScheme) private var colorScheme

    let skill: SkillService.SkillInfo
    /// Called after a successful uninstall — parent should refresh the list.
    var onUninstalled: (() -> Void)?

    @State private var showUninstallConfirm = false
    @State private var isUninstalling = false
    @State private var uninstallError: String?

    /// Resolved local path for Reveal in Finder. Nil if skill folder not found on disk.
    private var localPath: String? {
        let fm = FileManager.default

        // 1. Workspace skills: use the actual folder name from scan
        if let folder = skill.workspaceFolderName {
            let skillsDir = WorkspaceService.workspaceDirectory.appendingPathComponent("skills")
            let path = skillsDir.appendingPathComponent(folder).path
            if fm.fileExists(atPath: path) { return path }
        }

        // 2. Host skills: ~/.openclaw/skills/<name>
        let hostPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw/skills/\(skill.name)").path
        if fm.fileExists(atPath: hostPath) { return hostPath }

        // 3. Bundled skills: /opt/homebrew or /usr/local under node_modules
        if skill.bundled {
            let bundledPaths = [
                "/opt/homebrew/lib/node_modules/openclaw/skills/\(skill.name)",
                "/usr/local/lib/node_modules/openclaw/skills/\(skill.name)"
            ]
            for path in bundledPaths {
                if fm.fileExists(atPath: path) { return path }
            }
        }

        return nil
    }

    /// True if this skill is bundled OR lives in the host skills directory (~/.openclaw/skills/).
    private var isSystemSkill: Bool {
        if skill.bundled { return true }
        let hostPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw/skills/\(skill.name)").path
        return FileManager.default.fileExists(atPath: hostPath)
    }

    /// Registry URL. Only available for skills from the registry.
    /// Uses /skills/<slug> which 307 redirects to /<author>/<slug>.
    private var registryURL: URL? {
        guard skill.fromRegistry else { return nil }
        let slug = skill.registrySlug ?? skill.name
        return URL(string: "https://sable.ai/skills/\(slug)")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 24)

                descriptionSection
                    .padding(.bottom, 20)

                requirementsSection

                metadataSection
                    .padding(.bottom, 20)

                actionsSection
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 580, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(skill.emoji)
                .font(.system(size: 26))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous)
                        .fill(SableTheme.bgHover)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name)
                    .font(SableTypography.title)

                HStack(spacing: 10) {
                    statusPill

                    Text(skill.source)
                        .font(SableTypography.mono)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
    }

    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(skill.status.label)
                .font(SableTypography.captionMedium)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.10), in: Capsule())
    }

    private var statusColor: Color {
        switch skill.status {
        case .ready: SableTheme.success
        case .missing: SableTheme.warning
        case .disabled: SableTheme.textSecondary
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Description")
            Text(skill.description)
                .font(SableTypography.body)
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Requirements

    @ViewBuilder
    private var requirementsSection: some View {
        if !skill.missingBins.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Missing Requirements")
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(skill.missingBins, id: \.self) { bin in
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(SableTheme.warning)
                            Text(bin)
                                .font(SableTypography.codeBlock)
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Info")

            VStack(alignment: .leading, spacing: 6) {
                metadataRow("Source", value: skill.source)
                metadataRow("Bundled", value: skill.bundled ? "Yes" : "No")

                if let homepage = skill.homepage, !homepage.isEmpty {
                    HStack(spacing: 0) {
                        Text("Homepage")
                            .font(SableTypography.labelSmall)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(homepage)
                            .font(SableTypography.codeBlock)
                            .foregroundStyle(.primary.opacity(0.6))
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                    .fill(SableTheme.bgHover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                    .stroke(SableTheme.border)
            )
        }
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(SableTypography.labelSmall)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(SableTypography.labelSmall)
                .foregroundStyle(.primary.opacity(0.7))
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // Reveal in Finder — only enabled if local path exists
                Button {
                    if let path = localPath {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                        .font(SableTypography.labelSmall)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(localPath == nil)
                .help(localPath == nil ? "Skill folder not found on disk" : localPath!)

                // Homepage (if provided by CLI)
                if let homepage = skill.homepage,
                   let url = URL(string: homepage) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Homepage", systemImage: "safari")
                            .font(SableTypography.labelSmall)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // View in Registry — always available (constructed from slug)
                if let url = registryURL {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("View in Registry", systemImage: "globe")
                            .font(SableTypography.labelSmall)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()
            }

            // Uninstall / bundled notice
            if isSystemSkill {
                Text("Bundled with OpenClaw \u{00B7} Cannot be removed")
                    .font(SableTypography.caption)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 8) {
                    Button(role: .destructive) {
                        showUninstallConfirm = true
                    } label: {
                        Label("Uninstall", systemImage: "trash")
                            .font(SableTypography.labelSmall)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isUninstalling)

                    if isUninstalling {
                        ProgressView()
                            .controlSize(.small)
                        Text("Removing\u{2026}")
                            .font(SableTypography.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let error = uninstallError {
                        Text(error)
                            .font(SableTypography.caption)
                            .foregroundStyle(SableTheme.error)
                            .lineLimit(2)
                    }
                }
                .confirmationDialog(
                    "Uninstall \"\(skill.name)\"?",
                    isPresented: $showUninstallConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Uninstall", role: .destructive) {
                        performUninstall()
                    }
                } message: {
                    Text("This will remove the skill and its local files. You can reinstall it later from the registry.")
                }
            }
        }
    }

    private func performUninstall() {
        let slug = skill.registrySlug ?? skill.name
        isUninstalling = true
        uninstallError = nil

        Task {
            // Try sable uninstall to remove lockfile entry.
            // This may fail for locally imported skills (not in lockfile) — that's OK.
            let cliResult = await SkillService.uninstallSkill(slug: slug)

            // Always delete the actual folder if it exists on disk.
            if let folder = skill.workspaceFolderName {
                let skillsDir = WorkspaceService.workspaceDirectory.appendingPathComponent("skills")
                let folderPath = skillsDir.appendingPathComponent(folder)
                try? FileManager.default.removeItem(at: folderPath)
            }

            isUninstalling = false

            switch cliResult {
            case .success:
                onUninstalled?()
            case .failure:
                // If CLI failed but we deleted the folder, still treat as success
                if skill.workspaceFolderName != nil {
                    onUninstalled?()
                } else {
                    uninstallError = "Could not remove skill."
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(SableTypography.captionMedium)
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
