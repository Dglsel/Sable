import SwiftUI

// MARK: - Import Diagnostic Model

struct ImportDiagnostic: Identifiable {
    let id = UUID()
    let folderName: String
    let folderURL: URL
    let fileCount: Int
    let hasReadme: Bool
    let projectType: ProjectType

    enum ProjectType {
        /// Has openclaw keywords + cron/config folders
        case openclawConfig
        /// Has openclaw keywords but not a config pack
        case openclawProject
        /// Has package.json or scripts — generic dev project
        case genericProject
        /// Can't determine
        case unknown
    }

    /// Analyze a folder that lacks SKILL.md and produce a diagnostic report.
    static func diagnose(folder url: URL) -> ImportDiagnostic {
        let fm = FileManager.default
        let folderName = url.lastPathComponent

        let contents = (try? fm.contentsOfDirectory(atPath: url.path))?.filter { !$0.hasPrefix(".") } ?? []

        let hasReadme = contents.contains { $0.caseInsensitiveCompare("README.md") == .orderedSame }
        let hasPackageJSON = contents.contains { $0 == "package.json" }
        let hasCronPayloads = contents.contains { $0.lowercased().contains("cron") }
        let hasConfigs = contents.contains { $0.lowercased() == "configs" || $0.lowercased() == "config" }
        let hasScripts = contents.contains { $0.lowercased() == "scripts" }

        var isOpenClawRelated = false
        if hasReadme {
            let readmePath = contents.first { $0.caseInsensitiveCompare("README.md") == .orderedSame } ?? "README.md"
            if let readme = try? String(contentsOf: url.appendingPathComponent(readmePath), encoding: .utf8) {
                let lower = readme.lowercased()
                isOpenClawRelated = lower.contains("openclaw") || lower.contains("sable") || lower.contains("skill.md")
            }
        }

        let projectType: ProjectType
        if isOpenClawRelated && (hasCronPayloads || hasConfigs) {
            projectType = .openclawConfig
        } else if isOpenClawRelated {
            projectType = .openclawProject
        } else if hasPackageJSON || hasScripts {
            projectType = .genericProject
        } else {
            projectType = .unknown
        }

        return ImportDiagnostic(
            folderName: folderName,
            folderURL: url,
            fileCount: contents.count,
            hasReadme: hasReadme,
            projectType: projectType
        )
    }
}

// MARK: - Import Diagnostic Sheet

struct ImportDiagnosticSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let diagnostic: ImportDiagnostic

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(SableTheme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not a Skill Package")
                        .font(SableTypography.title)
                    Text(diagnostic.folderName)
                        .font(SableTypography.codeBlock)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    infoCard(
                        icon: "doc.questionmark",
                        title: "What happened",
                        body: "This folder does not contain a SKILL.md file, which is required for OpenClaw to recognize it as a skill."
                    )

                    switch diagnostic.projectType {
                    case .openclawConfig:
                        infoCard(
                            icon: "gearshape.2",
                            title: "This is an OpenClaw configuration project",
                            body: "This project contains configuration files (cron payloads, configs) that need manual setup. Check the README for instructions — typically involves copying files to your workspace and creating cron jobs via the terminal."
                        )
                    case .openclawProject:
                        infoCard(
                            icon: "cube",
                            title: "This is an OpenClaw project",
                            body: "This project is related to OpenClaw but is not packaged as a skill. Check the README for setup instructions — it may require terminal commands to install."
                        )
                    case .genericProject, .unknown:
                        infoCard(
                            icon: "questionmark.folder",
                            title: "Not an OpenClaw project",
                            body: "This folder doesn't appear to be an OpenClaw skill or configuration. A valid skill folder must contain a SKILL.md file with YAML frontmatter (name, description, emoji)."
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Valid SKILL.md example")
                            .font(SableTypography.captionMedium)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        Text("""
                        ---
                        name: my-skill
                        description: What this skill does
                        emoji: \u{1F4E6}
                        ---

                        Instructions for the agent...
                        """)
                        .font(SableTypography.mono)
                        .foregroundStyle(.primary.opacity(0.7))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                                .fill(SableTheme.bgHover)
                        )
                    }
                }
                .padding(20)
            }

            Divider()

            HStack(spacing: 8) {
                if diagnostic.hasReadme {
                    Button {
                        let readmePath = diagnostic.folderURL.appendingPathComponent("README.md")
                        NSWorkspace.shared.open(readmePath)
                    } label: {
                        Label("Open README", systemImage: "doc.text")
                            .font(SableTypography.labelSmall)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: diagnostic.folderURL.path)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                        .font(SableTypography.labelSmall)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 460, height: 480)
    }

    private func infoCard(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SableTypography.labelSmallMedium)
                Text(body)
                    .font(SableTypography.labelSmall)
                    .foregroundStyle(.primary.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
        }
    }
}
