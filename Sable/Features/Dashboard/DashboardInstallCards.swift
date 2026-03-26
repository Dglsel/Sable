import SwiftUI

/// Displays the appropriate install/onboarding card based on OpenClaw status.
struct DashboardInstallCards: View {
    @Environment(OpenClawService.self) private var openClaw
    @Environment(\.colorScheme) private var colorScheme

    var isDetecting: Bool
    var onRedetect: () -> Void

    @State private var showAdvancedInstall = false

    var body: some View {
        switch openClaw.status {
        case .notInstalled:
            freshInstallCard
        case .needsOnboarding:
            onboardingCard
        case .installedStopped, .running, .error:
            EmptyView()
        }
    }

    // MARK: - Panel A: Fresh Install

    private var freshInstallCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended Installation")
                .font(SableTypography.subtitle)

            Text(OpenClawInstallHint.installerDescription)
                .font(SableTypography.labelSmall)
                .foregroundStyle(.secondary)

            commandBlock(OpenClawInstallHint.installerCommand)

            Divider()

            advancedInstallSection

            Divider()

            actionBar(primaryCommand: OpenClawInstallHint.installerCommand)

            Text("Terminal will open a clean session to avoid shell config interference.")
                .font(SableTypography.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.05), lineWidth: 0.5)
        )
    }

    private var advancedInstallSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(SableAnimation.enter()) {
                    showAdvancedInstall.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(showAdvancedInstall ? 90 : 0))
                    Text("Advanced install options")
                        .font(SableTypography.labelSmall)
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showAdvancedInstall {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Manual steps (requires Node.js ≥ \(OpenClawInstallHint.minNodeVersion)):")
                        .font(SableTypography.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 10)

                    labeledCommandBlock(
                        label: "Step 1 — Install",
                        command: OpenClawInstallHint.npmInstallCommand
                    )
                    labeledCommandBlock(
                        label: "Step 2 — Quickstart setup",
                        command: OpenClawInstallHint.onboardCommand
                    )
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Panel B: Onboarding

    private var onboardingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quickstart Setup")
                .font(SableTypography.subtitle)

            VStack(alignment: .leading, spacing: 8) {
                setupStep(number: "1", text: "Open Terminal and run the command below")
                setupStep(number: "2", text: "Select your model provider (OpenAI, Anthropic, etc.)")
                setupStep(number: "3", text: "Skip channel selection — you'll chat directly in Sable")
                setupStep(number: "4", text: "Come back here — Sable will detect your gateway automatically")
            }

            commandBlock(OpenClawInstallHint.onboardCommand)

            Divider()

            HStack(spacing: 12) {
                Button {
                    openTerminal(with: OpenClawInstallHint.onboardCommand)
                } label: {
                    Label("Open in Terminal", systemImage: "terminal")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                CopyButton(text: OpenClawInstallHint.onboardCommand, style: .labeled)

                Button {
                    NSWorkspace.shared.open(OpenClawInstallHint.docsURL)
                } label: {
                    Label("Official Docs", systemImage: "book")
                }

                Spacer()

                redetectButton
            }
            .font(SableTypography.labelSmall)

            Text("After setup completes, Sable will detect your local gateway automatically and unlock Chat and Agents.")
                .font(SableTypography.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.05), lineWidth: 0.5)
        )
    }

    // MARK: - Shared Helpers

    private func setupStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
                .background(Color.primary.opacity(0.06), in: Circle())
            Text(text)
                .font(SableTypography.labelSmall)
                .foregroundStyle(.secondary)
        }
    }

    private func commandBlock(_ command: String) -> some View {
        HStack(spacing: 0) {
            Text(command)
                .font(SableTypography.codeBlock)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            Spacer()

            CopyButton(text: command)
                .padding(.trailing, 8)
        }
        .background(SableTheme.bgTertiary.opacity(0.5), in: RoundedRectangle(cornerRadius: SableRadius.lg))
    }

    private func labeledCommandBlock(label: String, command: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(SableTypography.labelSmallMedium)
                .foregroundStyle(.secondary)
            commandBlock(command)
        }
    }

    private func actionBar(primaryCommand: String) -> some View {
        HStack(spacing: 12) {
            Button {
                openTerminal(with: primaryCommand)
            } label: {
                Label("Open in Terminal", systemImage: "terminal")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            CopyButton(text: primaryCommand, style: .labeled)

            Button {
                NSWorkspace.shared.open(OpenClawInstallHint.docsURL)
            } label: {
                Label("Official Docs", systemImage: "book")
            }

            Spacer()

            redetectButton
        }
        .font(SableTypography.labelSmall)
    }

    private func openTerminal(with command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)

        let appleScriptSource = """
        tell application "Terminal"
            activate
            do script "/bin/zsh --no-rcs --no-globalrcs -i"
        end tell
        """

        if let appleScript = NSAppleScript(source: appleScriptSource) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    private var redetectButton: some View {
        Button {
            onRedetect()
        } label: {
            HStack(spacing: 4) {
                if isDetecting {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text("Re-detect")
            }
        }
        .disabled(isDetecting)
    }
}
