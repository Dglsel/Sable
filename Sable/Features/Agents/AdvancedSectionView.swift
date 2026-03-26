import SwiftUI

/// Read-only detail view for advanced sections (Bootstrap, Boot).
/// Shows the section's purpose, guide, and actual file content as a preview.
struct AdvancedSectionView: View {
    let section: AgentSection

    @Environment(\.colorScheme) private var colorScheme
    @State private var fileContent: String?
    @State private var isLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    guideCard
                    filePreview
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { loadFile() }
        .onChange(of: section) { _, _ in loadFile() }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
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

            Text("Advanced")
                .font(SableTypography.microMedium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: Capsule())

            if FileManager.default.fileExists(atPath: filePath) {
                Button {
                    NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                        .font(SableTypography.labelSmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Guide Card

    private var guideCard: some View {
        let guide = section.guide

        return VStack(alignment: .leading, spacing: 8) {
            Text(guide.what)
                .font(SableTypography.labelSmall)
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(guide.versus)
                .font(SableTypography.caption)
                .foregroundStyle(.secondary.opacity(0.6))
                .lineSpacing(2)
        }
    }

    // MARK: - File Preview

    @ViewBuilder
    private var filePreview: some View {
        if !isLoaded {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        } else if let content = fileContent, !content.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                    Text("File contents")
                        .font(SableTypography.microMedium)
                        .textCase(.uppercase)
                        .tracking(0.3)

                    Spacer()

                    let lineCount = content.components(separatedBy: .newlines).count
                    Text("\(lineCount) lines")
                        .font(SableTypography.micro)
                }
                .foregroundStyle(.tertiary)

                Text(content)
                    .font(SableTypography.codeBlock)
                    .foregroundStyle(.primary.opacity(0.7))
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                            .fill(SableTheme.bgHover)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                            .stroke(SableTheme.border)
                    )
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "doc")
                    .font(.system(size: 16))
                    .foregroundStyle(.quaternary)
                Text("\(section.fileName) is empty or does not exist yet.")
                    .font(SableTypography.labelSmall)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Data

    private var filePath: String {
        WorkspaceService.filePath(for: section).path
    }

    private func loadFile() {
        isLoaded = false
        fileContent = WorkspaceService.read(section)
        isLoaded = true
    }
}
