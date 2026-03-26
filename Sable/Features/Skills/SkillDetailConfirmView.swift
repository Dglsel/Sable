import SwiftUI

/// Detail confirmation view for a skill — shows metadata, install/reinstall button, registry link.
struct SkillDetailConfirmView: View {
    let detail: SkillService.SkillDetail
    let isInstalled: Bool
    var errorMessage: String?
    var showError: Bool = false
    var isInstalling: Bool = false
    var onInstall: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(detail.name)
                            .font(SableTypography.title)
                        if isInstalled {
                            Text("Installed")
                                .font(SableTypography.microMedium)
                                .foregroundStyle(SableTheme.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SableTheme.semanticBackground(SableTheme.success), in: Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        Text(detail.slug)
                            .font(SableTypography.mono)
                            .foregroundStyle(.tertiary)
                        if !detail.version.isEmpty {
                            Text("v\(detail.version)")
                                .font(SableTypography.microMedium)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                        }
                    }
                }

                if !detail.summary.isEmpty {
                    Text(detail.summary)
                        .font(SableTypography.labelSmall)
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Metadata
                VStack(alignment: .leading, spacing: 5) {
                    detailField("Author", value: detail.owner)
                    detailField("License", value: detail.license)
                    if !detail.updated.isEmpty {
                        detailField("Updated", value: formatDate(detail.updated))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                        .fill(SableTheme.bgHover)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                        .stroke(SableTheme.border)
                )

                // Error
                if showError, let error = errorMessage {
                    SkillErrorBanner(message: error)
                }

                // Actions
                HStack(spacing: 8) {
                    Button {
                        onInstall()
                    } label: {
                        Label(
                            isInstalled ? "Reinstall \(detail.name)" : "Install \(detail.name)",
                            systemImage: isInstalled ? "arrow.clockwise.circle" : "arrow.down.circle"
                        )
                        .font(SableTypography.labelSmallMedium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(isInstalling)

                    if let url = URL(string: "https://sable.ai/\(detail.owner)/\(detail.slug)") {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("View in Registry", systemImage: "globe")
                                .font(SableTypography.labelSmall)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    Spacer()
                }
            }
            .padding(20)
        }
    }

    private func detailField(_ label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(SableTypography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value.isEmpty ? "\u{2014}" : value)
                .font(SableTypography.caption)
                .foregroundStyle(.primary.opacity(0.7))
                .textSelection(.enabled)
        }
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: iso) else { return iso }
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
    }
}

// MARK: - Shared Error Banner

struct SkillErrorBanner: View {
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(SableTheme.error)
            Text(message)
                .font(SableTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: SableRadius.md, style: .continuous)
                .fill(SableTheme.semanticBackground(SableTheme.error))
        )
    }
}

// MARK: - Success View

struct SkillInstallSuccessView: View {
    let slug: String
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(SableTheme.success)

            Text("\"\(slug)\" installed successfully")
                .font(SableTypography.labelMedium)

            Text("The skills list has been refreshed.")
                .font(SableTypography.caption)
                .foregroundStyle(.secondary)

            Button("Done") { onDone() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
