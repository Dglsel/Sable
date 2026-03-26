import SwiftUI

struct DashboardView: View {
    @Environment(OpenClawService.self) private var openClaw

    @State private var isDetecting = false
    @State private var detectFeedback: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DashboardStatusPanel(isDetecting: isDetecting) {
                    Task { await performDetect() }
                }
                if let feedback = detectFeedback {
                    detectFeedbackBanner(feedback)
                }
                DashboardInstallCards(isDetecting: isDetecting) {
                    Task { await performDetect() }
                }
                if openClaw.status.isOnboarded {
                    DashboardDetailsSection()
                }
            }
            .padding(32)
            .frame(maxWidth: 640)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SableTheme.chatBackground)
        .onAppear { openClaw.setForeground(true) }
        .onDisappear { openClaw.setForeground(false) }
    }

    private func performDetect() async {
        isDetecting = true
        detectFeedback = nil

        let previousStatus = openClaw.status
        await openClaw.refresh()
        let newStatus = openClaw.status

        isDetecting = false

        if newStatus != previousStatus {
            // Status changed — the UI will update automatically, show positive feedback
            detectFeedback = feedbackForStatus(newStatus)
        } else {
            // No change — tell the user what's still going on
            detectFeedback = unchangedFeedback(for: newStatus)
        }

        // Auto-dismiss after 5 seconds
        Task {
            try? await Task.sleep(for: .seconds(5))
            if detectFeedback != nil {
                withAnimation(SableAnimation.enter(duration: SableAnimation.slow)) {
                    detectFeedback = nil
                }
            }
        }
    }

    private func feedbackForStatus(_ status: OpenClawStatus) -> String {
        switch status {
        case .notInstalled:
            "OpenClaw is not installed."
        case .needsOnboarding:
            "OpenClaw detected — complete setup to continue."
        case .installedStopped:
            "Setup complete. Start the gateway to begin chatting."
        case .running:
            "Gateway is running. You're ready to chat."
        case .error(let msg):
            "Error detected: \(msg)"
        }
    }

    private func unchangedFeedback(for status: OpenClawStatus) -> String {
        switch status {
        case .notInstalled:
            "No changes detected. OpenClaw is not yet installed."
        case .needsOnboarding:
            "No changes detected. Setup is still incomplete."
        case .installedStopped:
            "No changes detected. Gateway is still not running."
        case .running:
            "Gateway is still running."
        case .error:
            "No changes detected. Error persists."
        }
    }

    private func detectFeedbackBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(message)
                .font(SableTypography.labelSmall)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                withAnimation(SableAnimation.enter()) {
                    detectFeedback = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(SableTheme.bgHover, in: RoundedRectangle(cornerRadius: SableRadius.lg))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

}
