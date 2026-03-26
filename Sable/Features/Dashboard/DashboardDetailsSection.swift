import SwiftUI

/// Expandable details section showing version, gateway, config, workspace info.
struct DashboardDetailsSection: View {
    @Environment(OpenClawService.self) private var openClaw

    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(SableAnimation.enter()) {
                    showDetails.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .rotationEffect(.degrees(showDetails ? 90 : 0))
                        .foregroundStyle(.tertiary)
                    Text("Details")
                        .font(SableTypography.labelSmallMedium)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showDetails {
                detailsContent
                    .padding(.top, 10)
                    .transition(.opacity)
            }
        }
    }

    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let version = openClaw.status.version {
                detailRow(label: "Version", value: version)
                Divider().opacity(0.3).padding(.vertical, 6)
            }

            detailRow(
                label: "Gateway",
                value: openClaw.status.isRunning
                    ? "localhost:\(OpenClawInstallHint.defaultGatewayPort)"
                    : "Not running"
            )
            Divider().opacity(0.3).padding(.vertical, 6)

            detailRow(label: "Config", value: "~/.openclaw/openclaw.json")
            Divider().opacity(0.3).padding(.vertical, 6)

            detailRow(label: "Workspace", value: "~/.openclaw/workspace/")

            Text("Cron tasks, Ollama status, and logs will be available in a future update.")
                .font(SableTypography.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 10)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(SableTypography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(SableTypography.mono)
                .foregroundStyle(.primary.opacity(0.75))
                .textSelection(.enabled)
            Spacer()
        }
    }
}
