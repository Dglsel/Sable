import SwiftUI

/// Status card showing OpenClaw state + integrated start/stop/restart controls.
struct DashboardStatusPanel: View {
    @Environment(OpenClawService.self) private var openClaw
    @Environment(\.colorScheme) private var colorScheme

    var isDetecting: Bool
    var onHealthCheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status row
            HStack(spacing: 12) {
                if openClaw.transition != nil {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(SableTypography.title)
                    Text(statusSubtitle)
                        .font(SableTypography.labelSmall)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Integrated controls (only when onboarded)
            if openClaw.status.isOnboarded {
                Divider().padding(.horizontal, 16).opacity(0.15)

                HStack(spacing: 0) {
                    // Primary action
                    if openClaw.status.isRunning && openClaw.transition != .starting {
                        DashboardControlButton(
                            label: openClaw.transition == .stopping ? "Stopping…" : "Stop",
                            icon: "stop.fill",
                            isLoading: openClaw.transition == .stopping,
                            isPrimary: true
                        ) {
                            Task { await openClaw.stop() }
                        }
                        .disabled(openClaw.isBusy)
                    } else {
                        DashboardControlButton(
                            label: openClaw.transition == .starting ? "Starting…" : "Start",
                            icon: "play.fill",
                            isLoading: openClaw.transition == .starting,
                            isPrimary: true
                        ) {
                            Task { await openClaw.start() }
                        }
                        .disabled(openClaw.isBusy)
                    }

                    Spacer().frame(width: 16)

                    // Secondary actions as text links
                    SecondaryActionLink(
                        label: openClaw.transition == .restarting ? "Restarting…" : "Restart",
                        isLoading: openClaw.transition == .restarting
                    ) {
                        Task { await openClaw.restart() }
                    }
                    .disabled(openClaw.isBusy)

                    Text("·")
                        .font(SableTypography.labelSmall)
                        .foregroundStyle(Color.secondary.opacity(0.4))
                        .padding(.horizontal, 6)

                    SecondaryActionLink(
                        label: "Health Check",
                        isLoading: isDetecting
                    ) {
                        onHealthCheck()
                    }
                    .disabled(openClaw.isBusy || isDetecting)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous)
                .fill(SableTheme.bgHover)
        )
        .animation(SableAnimation.enter(), value: openClaw.transition)
    }

    // MARK: - Status Computed Properties

    private var statusColor: Color {
        switch openClaw.status {
        case .notInstalled: SableTheme.textSecondary
        case .needsOnboarding: SableTheme.warning
        case .installedStopped: SableTheme.warning
        case .running: SableTheme.success
        case .error: SableTheme.error
        }
    }

    private var statusTitle: String {
        if let transition = openClaw.transition {
            switch transition {
            case .starting: return "Starting OpenClaw…"
            case .stopping: return "Stopping OpenClaw…"
            case .restarting: return "Restarting OpenClaw…"
            }
        }
        switch openClaw.status {
        case .notInstalled: return "OpenClaw Not Detected"
        case .needsOnboarding: return "Complete OpenClaw Setup"
        case .installedStopped: return "OpenClaw Stopped"
        case .running: return "OpenClaw Running"
        case .error: return "OpenClaw Error"
        }
    }

    private var statusSubtitle: String {
        if let transition = openClaw.transition {
            switch transition {
            case .starting: return "Waiting for gateway to come online…"
            case .stopping: return "Waiting for gateway to shut down…"
            case .restarting: return "Waiting for gateway to restart…"
            }
        }
        switch openClaw.status {
        case .notInstalled:
            return "Install OpenClaw to get started."
        case .needsOnboarding(let v):
            if let v, !v.isEmpty { return "v\(v) — Setup required before you can chat." }
            else { return "Setup required before you can chat." }
        case .installedStopped(let v):
            if let v, !v.isEmpty { return "v\(v) — Gateway is not running." }
            else { return "Gateway is not running." }
        case .running(let v):
            if let v, !v.isEmpty { return "v\(v) — Gateway is active." }
            else { return "Gateway is active." }
        case .error(let msg):
            return msg
        }
    }
}
